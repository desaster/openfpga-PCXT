// IDE (hard-disk) service for the PicoRV32 disk softcore.
//
// The softcore masters ide.v's management bus the same way it masters floppy.v's:
// one transaction at a time over the shared bridge, with IDE_TARGET on the address
// register routing to ide.v (chip-select 0xF0) instead of the floppy controller
// (0xF2). The bridge RAM and the target-dataslot engine are shared with the floppy
// path.
//
// This is an ATA taskfile interpreter. ide.v raises a request when the guest resets
// the channel or writes a command; this code reads the taskfile, executes the
// command, and writes the taskfile back to complete it. Sector data moves through
// ide.v's 16-bit data port (mgmt register 0xF), fed from the HDD image dataslot.
// The register layout and command handling follow MiSTer's x86 support (ide.cpp /
// support/x86/x86.cpp), retargeted from the HPS to this softcore.

#include <stddef.h>

#include "softcpu_regs.h"

#define IDE_STATE_IDLE  0
#define IDE_STATE_RESET 1

// Bounded spin so a stalled dataslot read or a guest that abandons a transfer cannot
// hang the softcore (which would also stall floppy service). A real transfer completes
// in well under a millisecond; this is a few seconds of margin, never a false trip.
#define IDE_SPIN_LIMIT 4000000u

// Freestanding memset: clang -Os rewrites the IDENTIFY zero/space fills below as
// memset calls, so provide one. The volatile store keeps it from recognising this
// very loop as memset (which would recurse).
void *memset(void *s, int c, size_t n)
{
    volatile unsigned char *p = (volatile unsigned char *) s;
    while (n--) {
        *p++ = (unsigned char) c;
    }
    return s;
}

// One IDE management-bus write: latch the IDE target bit + register + 16-bit data,
// then trigger. IDE_TARGET routes the transaction to ide.v instead of floppy.v.
static void ide_mgmt_write(uint32_t reg, uint32_t data)
{
    *FDD_MGMT_ADDR = IDE_TARGET | (reg & 0xF);
    *FDD_MGMT_WDATA = data & 0xFFFF;
    *FDD_MGMT_TRIG = FDD_MGMT_WR;
}

// One IDE management-bus read: trigger, then return the captured value. The trigger
// and readback are separate instructions, so the single-cycle bus strobe and its
// capture have completed by the time the readback executes.
static uint32_t ide_mgmt_read(uint32_t reg)
{
    *FDD_MGMT_ADDR = IDE_TARGET | (reg & 0xF);
    *FDD_MGMT_TRIG = FDD_MGMT_RD;
    return *FDD_MGMT_RDATA & 0xFFFF;
}

// Pull one 512-byte sector from a drive's image dataslot into the bridge RAM. Mirror
// of the floppy helper: whole image, no partition offset, so file offset = lba*512.
// Returns non-zero on success, zero if the transfer timed out.
static int ide_pull_sector(uint32_t slot, uint32_t lba)
{
    *FDD_TDS_ID = slot;
    *FDD_TDS_OFFSET = lba * SECTOR_BYTES;
    *FDD_TDS_BRIDGE = FDD_BRIDGE_BASE;
    *FDD_TDS_LENGTH = SECTOR_BYTES;
    *FDD_TDS_CLR = 1;
    *FDD_TDS_TRIG = FDD_TDS_READ;
    uint32_t to = IDE_SPIN_LIMIT;
    while (!(*FDD_TDS_STATUS & FDD_TDS_DONE) && --to) {
    }
    return to != 0;
}

// Persist the 512-byte sector now in the bridge RAM to a drive's image dataslot at this
// LBA. Mirror of ide_pull_sector with the transfer reversed; the write reaches the SD
// file directly (deferload, no flush). Returns non-zero on success, zero on timeout.
static int ide_write_sector(uint32_t slot, uint32_t lba)
{
    *FDD_TDS_ID = slot;
    *FDD_TDS_OFFSET = lba * SECTOR_BYTES;
    *FDD_TDS_BRIDGE = FDD_BRIDGE_BASE;
    *FDD_TDS_LENGTH = SECTOR_BYTES;
    *FDD_TDS_CLR = 1;
    *FDD_TDS_TRIG = FDD_TDS_WRITE;
    uint32_t to = IDE_SPIN_LIMIT;
    while (!(*FDD_TDS_STATUS & FDD_TDS_DONE) && --to) {
    }
    return to != 0;
}

// Per-drive geometry and IDENTIFY data. The primary IDE channel carries two drives,
// master (0) and slave (1); the taskfile's drv bit selects one. dsel points at the
// drive the current command addresses, refreshed whenever the taskfile is read;
// ide_state (the reset/idle FSM) is shared by the channel.
struct hdd_drive {
    uint32_t total; // total sectors (image size / 512)
    uint32_t spt;   // sectors per track
    uint32_t heads; // heads
    uint32_t cyls;  // cylinders
    uint32_t spb;   // sectors per block for READ/WRITE MULTIPLE (set by 0xC6)
    int present;
    uint16_t id[256]; // IDENTIFY block, built at mount
};
static struct hdd_drive hdd[2];
static struct hdd_drive *dsel = &hdd[0];
static int ide_state;

// Dataslot id backing a drive's image.
static uint32_t hdd_slot(uint32_t drive)
{
    return drive ? HDD1_SLOT_ID : HDD0_SLOT_ID;
}

// The taskfile of the request currently being serviced.
static struct {
    uint32_t features;
    uint32_t sector_count;
    uint32_t sector;   // LBA[7:0] in LBA mode
    uint32_t cylinder; // LBA[23:8] in LBA mode
    uint32_t head;     // LBA[27:24] in LBA mode
    uint32_t drv;
    uint32_t lba; // LBA vs CHS addressing
    uint32_t cmd;
    uint32_t error;
    uint32_t status;
    uint32_t io_size; // sectors this data phase transfers
} R;

// Read the taskfile: mgmt regs 0-5 unpacked per ide.v's read map. Only the 28-bit
// LBA fields are needed (regs 0,1,2,5); the reg 3/4 high bytes are 48-bit LBA, which
// the XT-IDE BIOS does not use.
static void ide_get_regs(void)
{
    uint32_t r0 = ide_mgmt_read(0);
    uint32_t r1 = ide_mgmt_read(1);
    uint32_t r2 = ide_mgmt_read(2);
    uint32_t r5 = ide_mgmt_read(5);

    R.features = (r0 >> 8) & 0xFF;
    R.sector_count = r1 & 0xFF;
    R.sector = (r1 >> 8) & 0xFF;
    R.cylinder = r2 & 0xFFFF;
    R.head = r5 & 0xF;
    R.drv = (r5 >> 4) & 1;
    R.lba = (r5 >> 6) & 1;
    R.cmd = (r5 >> 8) & 0xFF;
    dsel = &hdd[R.drv];

    R.error = 0;
    R.status = 0;
    R.io_size = 0;
}

// Complete a command by writing the taskfile back: reg 0 first (sets the data-phase
// block size and error), reg 5 last (sets status, pulses IRQ, and clears the
// request). DSC is injected unless BSY/ERR are set, matching the RTL's expectations.
static void ide_set_regs(void)
{
    if (!(R.status & (ATA_BSY | ATA_ERR))) {
        R.status |= ATA_DSC;
    }

    uint32_t drivehead = (R.lba ? 0xE0 : 0xA0) | (R.drv ? 0x10 : 0x00) | (R.head & 0xF);

    ide_mgmt_write(0, (R.io_size & 0xFF) | ((R.error & 0xFF) << 8));
    ide_mgmt_write(1, (R.sector_count & 0xFF) | ((R.sector & 0xFF) << 8));
    ide_mgmt_write(2, R.cylinder & 0xFFFF);
    ide_mgmt_write(3, ((R.sector_count >> 8) & 0xFF) | (((R.sector >> 8) & 0xFF) << 8));
    ide_mgmt_write(4, (R.cylinder >> 16) & 0xFFFF);
    ide_mgmt_write(5, drivehead | ((R.status & 0xFF) << 8));
}

// Stream 256 words from a source into the data port. Every reg-0xF write pushes one
// 16-bit word and auto-increments the buffer pointer, so the address is set once.
static void ide_push_identify(void)
{
    *FDD_MGMT_ADDR = IDE_TARGET | IMGMT_DATA;
    for (int i = 0; i < 256; i++) {
        *FDD_MGMT_WDATA = dsel->id[i];
        *FDD_MGMT_TRIG = FDD_MGMT_WR;
    }
}

// Stream the 512-byte sector in the bridge RAM into the data port. The RAM holds it
// little-endian, so each 32-bit word feeds the low half then the high half, landing
// file byte 0 in the low byte of the guest's first 16-bit read.
static void ide_push_sector(void)
{
    *FDD_BRAM_ADDR = 0;
    *FDD_MGMT_ADDR = IDE_TARGET | IMGMT_DATA;
    for (int i = 0; i < SECTOR_WORDS; i++) {
        uint32_t w = *FDD_BRAM_RDATA;
        *FDD_MGMT_WDATA = w & 0xFFFF;
        *FDD_MGMT_TRIG = FDD_MGMT_WR;
        *FDD_MGMT_WDATA = (w >> 16) & 0xFFFF;
        *FDD_MGMT_TRIG = FDD_MGMT_WR;
    }
}

// Drain the 512-byte sector the guest wrote into ide.v's data buffer back into the
// bridge RAM. Mirror of ide_push_sector: each reg-0xF read pops one 16-bit word and
// auto-increments the buffer pointer, so the address is set once. The low half lands
// in the low bytes of the RAM word, keeping the image little-endian.
static void ide_drain_sector(void)
{
    *FDD_BRAM_ADDR = 0;
    *FDD_MGMT_ADDR = IDE_TARGET | IMGMT_DATA;
    for (int i = 0; i < SECTOR_WORDS; i++) {
        *FDD_MGMT_TRIG = FDD_MGMT_RD;
        uint32_t lo = *FDD_MGMT_RDATA & 0xFFFF;
        *FDD_MGMT_TRIG = FDD_MGMT_RD;
        uint32_t hi = *FDD_MGMT_RDATA & 0xFFFF;
        *FDD_BRAM_WDATA = lo | (hi << 16);
    }
}

// Set the CHS translation and recompute cylinders from it. 0x91 (init device
// parameters) uses this to adopt the geometry the guest wants.
static void ide_set_geometry(struct hdd_drive *d, uint32_t spt, uint32_t heads)
{
    d->heads = heads ? heads : 16;
    d->spt = spt ? spt : 256;
    uint32_t cyls = d->total / (d->heads * d->spt);
    if (cyls > 65535) {
        cyls = 65535;
    }
    d->cyls = cyls;
}

// LBA of the addressed sector, from the taskfile's LBA or CHS fields.
static uint32_t ide_get_lba(void)
{
    if (R.lba) {
        return R.sector | (R.cylinder << 8) | (R.head << 24);
    }
    return ((R.cylinder * dsel->heads + R.head) * dsel->spt) + (R.sector - 1);
}

// Write a completed LBA back into the taskfile so the guest sees progress. Stores
// the last transferred sector (lba-1), in whichever addressing mode is active.
static void ide_put_lba(uint32_t lba)
{
    lba--;
    if (R.lba) {
        R.sector = lba & 0xFF;
        R.cylinder = (lba >> 8) & 0xFFFF;
        R.head = (lba >> 24) & 0xF;
    } else {
        uint32_t hspt = dsel->heads * dsel->spt;
        R.cylinder = lba / hspt;
        lba = lba % hspt;
        R.head = lba / dsel->spt;
        R.sector = (lba % dsel->spt) + 1;
    }
}

// READ SECTOR(S) / READ MULTIPLE: transfer sectors until the count is exhausted. In
// single mode one sector is a data phase; in multiple mode up to the drive's block size
// sectors are streamed into ide.v's buffer and delivered as one phase (io_size = the
// block). The guest drains each phase and ide.v re-requests (req 5) for the next; END on
// the last stops it re-requesting.
static void ide_process_read(int multi)
{
    uint32_t lba = ide_get_lba();
    uint32_t remaining = R.sector_count ? R.sector_count : 256;
    uint32_t slot = hdd_slot(R.drv);

    while (1) {
        uint32_t cnt = 1;
        if (multi) {
            cnt = (remaining < dsel->spb) ? remaining : dsel->spb;
            if (!cnt) {
                cnt = 1;
            }
        }

        // Each sector pushes 256 words to the data port; the port address is never a
        // non-data register between them, so ide.v's buffer pointer keeps counting and
        // the block lands contiguously.
        int ok = 1;
        for (uint32_t s = 0; s < cnt; s++) {
            if (!ide_pull_sector(slot, lba + s)) {
                ok = 0;
                break;
            }
            ide_push_sector();
        }

        lba += cnt;
        remaining -= cnt;
        ide_put_lba(lba);
        R.sector_count = remaining;
        R.io_size = cnt;

        if (!ok) {
            // A dataslot read stalled; report an error rather than stream stale data.
            R.status = ATA_RDY | ATA_ERR | ATA_IRQ;
            R.error = ATA_ERR_ABRT;
            ide_set_regs();
            ide_state = IDE_STATE_IDLE;
            break;
        }

        R.status = ATA_RDY | ATA_DRQ | ATA_IRQ;
        if (!remaining) {
            R.status |= ATA_END;
        }
        ide_set_regs();

        if (!remaining) {
            ide_state = IDE_STATE_IDLE;
            break;
        }

        uint32_t req = 0;
        uint32_t to = IDE_SPIN_LIMIT;
        while (!req && --to) {
            req = *IDE_REQUEST;
        }
        if (req != IDE_REQ_DATA) {
            ide_state = IDE_STATE_IDLE;
            break;
        }
    }
}

// WRITE SECTOR(S) / WRITE MULTIPLE: the mirror of ide_process_read with the data
// direction reversed. Each pass sets DRQ to request a block, waits for the guest to
// fill ide.v's buffer (req 5), then drains the block sector by sector and persists it.
// The first block carries no IRQ (the command itself started it); every later block
// and the final completion do, matching the ATA PIO-out handshake. END is never set,
// so the controller re-requests after each block until the count is exhausted.
static void ide_process_write(int multi)
{
    uint32_t lba = ide_get_lba();
    uint32_t remaining = R.sector_count ? R.sector_count : 256;
    uint32_t slot = hdd_slot(R.drv);
    uint32_t irq = 0;

    while (1) {
        uint32_t cnt = 1;
        if (multi) {
            cnt = (remaining < dsel->spb) ? remaining : dsel->spb;
            if (!cnt) {
                cnt = 1;
            }
        }

        R.sector_count = remaining;
        R.io_size = cnt;
        R.status = ATA_RDY | ATA_DRQ | irq;
        irq = ATA_IRQ;
        ide_set_regs();

        uint32_t req = 0;
        uint32_t to = IDE_SPIN_LIMIT;
        while (!req && --to) {
            req = *IDE_REQUEST;
        }
        if (req != IDE_REQ_DATA) {
            ide_state = IDE_STATE_IDLE;
            break;
        }

        // The block streamed contiguously into ide.v's buffer; drain each sector into
        // the bridge RAM (mgmt_cnt keeps counting across them) and write it to the SD.
        int ok = 1;
        for (uint32_t s = 0; s < cnt; s++) {
            ide_drain_sector();
            if (!ide_write_sector(slot, lba + s)) {
                ok = 0;
                break;
            }
        }

        lba += cnt;
        remaining -= cnt;
        ide_put_lba(lba);
        R.sector_count = remaining;

        if (!ok) {
            // A dataslot write stalled; report an error rather than lose more data.
            R.status = ATA_RDY | ATA_ERR | ATA_IRQ;
            R.error = ATA_ERR_ABRT;
            ide_set_regs();
            ide_state = IDE_STATE_IDLE;
            break;
        }

        if (!remaining) {
            R.status = ATA_RDY | ATA_IRQ;
            ide_set_regs();
            ide_state = IDE_STATE_IDLE;
            break;
        }
    }
}

// Execute the command in the taskfile. Returns non-zero to abort (unsupported or
// failed), which the caller reports as RDY|ERR|IRQ with error=ABRT.
static int ide_handle_cmd(void)
{
    if (R.cmd >= 0x10 && R.cmd <= 0x1F) { // recalibrate
        R.status = ATA_RDY | ATA_IRQ;
        R.cylinder = 0;
        ide_set_regs();
        return 0;
    }

    switch (R.cmd) {
    case 0xEC: // identify device
        R.io_size = 1;
        R.status = ATA_RDY | ATA_DRQ | ATA_IRQ | ATA_END;
        ide_push_identify();
        ide_set_regs();
        break;

    case 0x20: // read sectors with retry
    case 0x21: // read sectors
        ide_process_read(0);
        break;

    case 0x30: // write sectors with retry
    case 0x31: // write sectors
        ide_process_write(0);
        break;

    case 0xC4: // read multiple
        ide_process_read(1);
        break;

    case 0xC5: // write multiple
        ide_process_write(1);
        break;

    case 0xC6:                     // set multiple mode: block size for READ MULTIPLE
        if (R.sector_count > 32) { // capped by IDENTIFY word 47 (max 32)
            return 1;
        }
        dsel->spb = R.sector_count ? R.sector_count : 1;
        R.status = ATA_RDY | ATA_IRQ;
        ide_set_regs();
        break;

    case 0x91: // initialize device parameters
        ide_set_geometry(dsel, R.sector_count, R.head + 1);
        R.status = ATA_RDY | ATA_IRQ;
        ide_set_regs();
        break;

    case 0x40: // read verify
        R.status = ATA_RDY | ATA_IRQ;
        ide_set_regs();
        break;

    default:
        return 1;
    }

    return 0;
}

// Build a drive's 256-word IDENTIFY block from the geometry ide_set_geometry derived.
static void build_identify(struct hdd_drive *d)
{
    uint16_t *id = d->id;

    for (int i = 0; i < 256; i++) {
        id[i] = 0;
    }

    id[0] = 0x0040;
    id[1] = d->cyls;
    id[3] = d->heads;
    id[4] = 512 * d->spt;
    id[5] = 512;
    id[6] = d->spt;
    id[10] = ('A' << 8) | 'O'; // serial number
    id[11] = ('H' << 8) | 'D';
    id[12] = ('0' << 8) | '0';
    id[13] = ('0' << 8) | '0';
    id[14] = ('0' << 8) | ' ';
    for (int i = 15; i <= 19; i++) {
        id[i] = (' ' << 8) | ' ';
    }
    id[20] = 3;
    id[21] = 512;
    id[22] = 4;
    for (int i = 27; i <= 46; i++) { // model number, space-padded
        id[i] = (' ' << 8) | ' ';
    }
    id[27] = ('P' << 8) | 'C'; // "PCXT HARDDISK", byte-swapped ATA order
    id[28] = ('X' << 8) | 'T';
    id[29] = (' ' << 8) | 'H';
    id[30] = ('A' << 8) | 'R';
    id[31] = ('D' << 8) | 'D';
    id[32] = ('I' << 8) | 'S';
    id[33] = ('K' << 8) | ' ';
    id[47] = 0x8020;
    id[48] = 1;
    id[49] = 1 << 9; // LBA supported
    id[50] = 0x4001;
    id[51] = 0x0200;
    id[52] = 0x0200;
    id[53] = 0x0007;
    id[54] = d->cyls;
    id[55] = d->heads;
    id[56] = d->spt;
    id[57] = d->total & 0xFFFF;
    id[58] = d->total >> 16;
    id[59] = 0x110;
    id[60] = d->total & 0xFFFF; // LBA-28 capacity
    id[61] = d->total >> 16;
    id[65] = 120;
    id[66] = 120;
    id[67] = 120;
    id[68] = 120;
    id[80] = 0x007E;
    id[82] = (1 << 14) | (1 << 9);
    id[83] = (1 << 14) | (1 << 13) | (1 << 12);
    id[84] = 1 << 14;
    id[85] = (1 << 14) | (1 << 9);
    id[86] = (1 << 14) | (1 << 13) | (1 << 12);
    id[87] = 1 << 14;
    id[93] = (1 << 14) | (1 << 13) | (1 << 9) | (1 << 8) | (1 << 3) | (1 << 1) | (1 << 0);
    id[100] = d->total & 0xFFFF; // LBA-48 capacity
    id[101] = d->total >> 16;
}

// Commit a drive's present bit through ide.v mgmt reg 6. Drive 0 uses write-enable bit
// 3 with the present bit at 0; drive 1 uses write-enable bit 7 with the present bit at 4.
static void ide_set_present(uint32_t drive, int present)
{
    if (drive) {
        ide_mgmt_write(IMGMT_PRESENT, IDE_DRV1_WE | (present ? (IDE_PRESENT << 4) : 0));
    } else {
        ide_mgmt_write(IMGMT_PRESENT, IDE_DRV0_WE | (present ? IDE_PRESENT : 0));
    }
}

// Mark both drives absent so the BIOS finds no disk and boots from floppy. Also clears a
// stale-present state after a warm reset before any image is mounted.
void ide_init(void)
{
    hdd[0].present = 0;
    hdd[1].present = 0;
    ide_state = IDE_STATE_IDLE;
    ide_set_present(0, 0);
    ide_set_present(1, 0);
}

// Classic AT fixed-disk types {cylinders, heads, sectors}. An image whose total
// sector count matches an entry exactly takes that entry's geometry, the same as
// MiSTer's x86 support (support/x86/x86.cpp hdd_table). A disk partitioned there
// stores CHS values for this geometry, so the geometries have to agree or the boot's
// CHS read of the VBR lands on the wrong sector.
static const uint16_t hdd_table[][3] = {
    { 306, 4, 17 },
    { 615, 2, 17 },
    { 306, 4, 26 },
    { 1024, 2, 17 },
    { 697, 3, 17 },
    { 306, 8, 17 },
    { 614, 4, 17 },
    { 615, 4, 17 },
    { 670, 4, 17 },
    { 697, 4, 17 },
    { 987, 3, 17 },
    { 820, 4, 17 },
    { 670, 5, 17 },
    { 697, 5, 17 },
    { 733, 5, 17 },
    { 615, 6, 17 },
    { 462, 8, 17 },
    { 306, 8, 26 },
    { 615, 4, 26 },
    { 1024, 4, 17 },
    { 855, 5, 17 },
    { 925, 5, 17 },
    { 932, 5, 17 },
    { 1024, 2, 40 },
    { 809, 6, 17 },
    { 976, 5, 17 },
    { 977, 5, 17 },
    { 698, 7, 17 },
    { 699, 7, 17 },
    { 981, 5, 17 },
    { 615, 8, 17 },
    { 989, 5, 17 },
    { 820, 4, 26 },
    { 1024, 5, 17 },
    { 733, 7, 17 },
    { 754, 7, 17 },
    { 733, 5, 26 },
    { 940, 6, 17 },
    { 615, 6, 26 },
    { 462, 8, 26 },
    { 830, 7, 17 },
    { 855, 7, 17 },
    { 751, 8, 17 },
    { 1024, 4, 26 },
    { 918, 7, 17 },
    { 925, 7, 17 },
    { 855, 5, 26 },
    { 977, 7, 17 },
    { 987, 7, 17 },
    { 1024, 7, 17 },
    { 823, 4, 38 },
    { 925, 8, 17 },
    { 809, 6, 26 },
    { 976, 5, 26 },
    { 977, 5, 26 },
    { 698, 7, 26 },
    { 699, 7, 26 },
    { 940, 8, 17 },
    { 615, 8, 26 },
    { 1024, 5, 26 },
    { 733, 7, 26 },
    { 1024, 8, 17 },
    { 823, 10, 17 },
    { 754, 11, 17 },
    { 830, 10, 17 },
    { 925, 9, 17 },
    { 1224, 7, 17 },
    { 940, 6, 26 },
    { 855, 7, 26 },
    { 751, 8, 26 },
    { 1024, 9, 17 },
    { 965, 10, 17 },
    { 969, 5, 34 },
    { 980, 10, 17 },
    { 960, 5, 35 },
    { 918, 11, 17 },
    { 1024, 10, 17 },
    { 977, 7, 26 },
    { 1024, 7, 26 },
    { 1024, 11, 17 },
    { 940, 8, 26 },
    { 776, 8, 33 },
    { 755, 16, 17 },
    { 1024, 12, 17 },
    { 1024, 8, 26 },
    { 823, 10, 26 },
    { 830, 10, 26 },
    { 925, 9, 26 },
    { 960, 9, 26 },
    { 1024, 13, 17 },
    { 1224, 11, 17 },
    { 900, 15, 17 },
    { 969, 7, 34 },
    { 917, 15, 17 },
    { 918, 15, 17 },
    { 1524, 4, 39 },
    { 1024, 9, 26 },
    { 1024, 14, 17 },
    { 965, 10, 26 },
    { 980, 10, 26 },
    { 1020, 15, 17 },
    { 1023, 15, 17 },
    { 1024, 15, 17 },
    { 1024, 16, 17 },
    { 1224, 15, 17 },
    { 755, 16, 26 },
    { 903, 8, 46 },
    { 984, 10, 34 },
    { 900, 15, 26 },
    { 917, 15, 26 },
    { 1023, 15, 26 },
    { 684, 16, 38 },
    { 1930, 4, 62 },
    { 967, 16, 31 },
    { 1013, 10, 63 },
    { 1218, 15, 36 },
    { 654, 16, 63 },
    { 659, 16, 63 },
    { 702, 16, 63 },
    { 1002, 13, 63 },
    { 854, 16, 63 },
    { 987, 16, 63 },
    { 995, 16, 63 },
    { 1024, 16, 63 },
    { 1036, 16, 63 },
    { 1120, 16, 59 },
    { 1054, 16, 63 },
};

// If the image size matches a classic AT type exactly, take its heads and spt.
static int find_at_geometry(uint32_t sectors, uint32_t *spt, uint32_t *heads)
{
    int n = sizeof(hdd_table) / sizeof(hdd_table[0]);
    for (int i = 0; i < n; i++) {
        uint32_t c = hdd_table[i][0];
        uint32_t h = hdd_table[i][1];
        uint32_t s = hdd_table[i][2];
        if (c * h * s == sectors) {
            *spt = s;
            *heads = h;
            return 1;
        }
    }
    return 0;
}

// Bring a drive online: derive geometry, build IDENTIFY, mark it present.
void ide_mount(uint32_t drive, uint32_t sectors)
{
    struct hdd_drive *d = &hdd[drive];
    d->total = sectors;
    d->spb = 16; // default READ/WRITE MULTIPLE block, matching IDENTIFY word 59; 0xC6 changes it
    // A classic AT type by exact size, else 63 spt / 16 heads up to 8 GB (16383*16*63),
    // else LBA-only. This must agree with the geometry the disk was partitioned under so
    // the boot's CHS read of the VBR resolves to the right sector.
    uint32_t spt, heads;
    if (!find_at_geometry(sectors, &spt, &heads)) {
        heads = 16;
        spt = (sectors > 16514064u) ? 256 : 63;
    }
    ide_set_geometry(d, spt, heads);
    build_identify(d);
    d->present = 1;
    ide_set_present(drive, 1);
}

// Whether the selected drive has an image mounted. Keying on the selected drive, not a
// channel-wide flag, keeps an absent drive's commands aborting and its reset signature
// reporting "no device" while the other drive stays live.
static int drive_present(uint32_t drv)
{
    return hdd[drv].present;
}

// Answer one pending IDE request. A reset loads the ATA signature and parks the
// channel BSY until the guest releases it; a command reads the taskfile and executes
// it, aborting if the drive is absent or the command is unsupported.
void ide_poll(void)
{
    uint32_t req = *IDE_REQUEST;

    if (req == IDE_REQ_IDLE) {
        if (ide_state == IDE_STATE_RESET) {
            ide_state = IDE_STATE_IDLE;
            R.status = ATA_RDY;
            ide_set_regs();
        }
    } else if (req == IDE_REQ_CMD) {
        ide_state = IDE_STATE_IDLE;
        ide_get_regs();
        int err = drive_present(R.drv) ? ide_handle_cmd() : 1;
        if (err) {
            R.status = ATA_RDY | ATA_ERR | ATA_IRQ;
            R.error = ATA_ERR_ABRT;
            ide_set_regs();
        }
    } else if (req == IDE_REQ_DATA) {
        // Data phase outside a transfer: nothing queued it, so abort.
        ide_state = IDE_STATE_IDLE;
        R.status = ATA_RDY | ATA_ERR | ATA_IRQ;
        R.error = ATA_ERR_ABRT;
        ide_set_regs();
    } else if (req == IDE_REQ_RESET) {
        ide_get_regs();
        R.head = 0;
        R.error = 0;
        R.sector = 1;
        R.sector_count = 1;
        R.cylinder = drive_present(R.drv) ? 0x0000 : 0xFFFF;
        R.status = ATA_BSY;
        ide_set_regs();
        ide_state = IDE_STATE_RESET;
    }
}
