// Floppy service loop for the PicoRV32 disk softcore.
//
// The controller (floppy.v) raises a request whenever it needs to move a sector,
// and this code answers it over the management bus. A read request: fetch the LBA,
// pull that sector from the drive-A dataslot into the bridge RAM over the APF
// target-dataslot handshake, then stream the 512 bytes into the controller's
// management FIFO. A write request is the mirror: drain the 512 bytes the
// controller has queued in that FIFO into the bridge RAM, then persist them to the
// dataslot. Each pass moves one sector and runs again while the request holds.
//
// Written sectors reach the SD file through target-dataslot writes.
//
// The geometry table and the register protocol follow MiSTer's x86 support
// (Main_MiSTer support/x86/x86.cpp), retargeted from the HPS to this softcore.

#include "softcpu_regs.h"

// One management-bus write: latch drive + register + 16-bit data, then trigger.
static void mgmt_write(uint32_t drive, uint32_t reg, uint32_t data)
{
    *FDD_MGMT_ADDR = (drive << 4) | (reg & 0xF);
    *FDD_MGMT_WDATA = data & 0xFFFF;
    *FDD_MGMT_TRIG = FDD_MGMT_WR;
}

// One management-bus read: trigger, then return the captured value. The trigger
// and the readback are separate instructions, so the single-cycle bus strobe and
// its capture have completed by the time the readback executes.
static uint32_t mgmt_read(uint32_t drive, uint32_t reg)
{
    *FDD_MGMT_ADDR = (drive << 4) | (reg & 0xF);
    *FDD_MGMT_TRIG = FDD_MGMT_RD;
    return *FDD_MGMT_RDATA & 0xFFFF;
}

// Pull one 512-byte sector from a dataslot into the bridge RAM and wait for it.
static void pull_sector(uint32_t slot_id, uint32_t lba)
{
    *FDD_TDS_ID = slot_id;
    *FDD_TDS_OFFSET = lba * SECTOR_BYTES;
    *FDD_TDS_BRIDGE = FDD_BRIDGE_BASE;
    *FDD_TDS_LENGTH = SECTOR_BYTES;
    *FDD_TDS_CLR = 1;
    *FDD_TDS_TRIG = FDD_TDS_READ;
    while (!(*FDD_TDS_STATUS & FDD_TDS_DONE)) {
    }
}

// Stream the 512 bytes now in the bridge RAM into the controller FIFO, in order.
// The bridge RAM holds the sector little-endian, so the low byte of each word is
// the earlier file byte. The FIFO register address is set once for the whole run.
static void push_sector(uint32_t drive)
{
    *FDD_BRAM_ADDR = 0;
    *FDD_MGMT_ADDR = (drive << 4) | FMGMT_FIFO;
    for (int i = 0; i < SECTOR_WORDS; i++) {
        uint32_t w = *FDD_BRAM_RDATA;
        for (int b = 0; b < 4; b++) {
            *FDD_MGMT_WDATA = (w >> (b * 8)) & 0xFF;
            *FDD_MGMT_TRIG = FDD_MGMT_WR;
        }
    }
}

// Drain the 512 bytes the controller has queued for a write out of its FIFO and
// into the bridge RAM, in order. Mirror of push_sector: the first byte popped is
// the earliest file byte, so it lands in the low byte of the first RAM word. The
// FIFO register address is set once for the whole run.
static void pull_fifo(uint32_t drive)
{
    *FDD_BRAM_ADDR = 0;
    *FDD_MGMT_ADDR = (drive << 4) | FMGMT_FIFO;
    for (int i = 0; i < SECTOR_WORDS; i++) {
        uint32_t w = 0;
        for (int b = 0; b < 4; b++) {
            *FDD_MGMT_TRIG = FDD_MGMT_RD;
            w |= (*FDD_MGMT_RDATA & 0xFF) << (b * 8);
        }
        *FDD_BRAM_WDATA = w;
    }
}

// Persist the 512 bytes now in the bridge RAM to the drive-A dataslot at this LBA
// over the APF target-dataslot write handshake. Mirror of pull_sector.
static void write_sector(uint32_t slot_id, uint32_t lba)
{
    *FDD_TDS_ID = slot_id;
    *FDD_TDS_OFFSET = lba * SECTOR_BYTES;
    *FDD_TDS_BRIDGE = FDD_BRIDGE_BASE;
    *FDD_TDS_LENGTH = SECTOR_BYTES;
    *FDD_TDS_CLR = 1;
    *FDD_TDS_TRIG = FDD_TDS_WRITE;
    while (!(*FDD_TDS_STATUS & FDD_TDS_DONE)) {
    }
}

// Standard PC floppy geometries, largest first; the first whose sector count the
// image meets wins. Matches the size thresholds MiSTer's x86 support uses.
struct fdd_geom {
    uint32_t min_sectors;
    uint32_t cyls;
    uint32_t spt;
    uint32_t heads;
};

static const struct fdd_geom fdd_geoms[] = {
    { 5760, 80, 36, 2 }, // 2.88 MB
    { 3360, 80, 21, 2 }, // 1.68 MB
    { 2880, 80, 18, 2 }, // 1.44 MB
    { 2400, 80, 15, 2 }, // 1.2 MB
    { 1440, 80, 9, 2 },  // 720 KB
    { 720, 40, 9, 2 },   // 360 KB
    { 640, 40, 8, 2 },   // 320 KB
    { 360, 40, 9, 1 },   // 180 KB
    { 0, 40, 8, 1 },     // 160 KB
};

// Crude busy-wait, long enough to separate the eject from the insert below.
static void spin(uint32_t n)
{
    for (volatile uint32_t i = 0; i < n; i++) {
    }
}

// Derive the drive-A geometry from the image size (in sectors) and push it to the
// controller, ejecting first so the controller flags a media change, then marking
// the media present and writable.
void fdd_mount(uint32_t sectors)
{
    const struct fdd_geom *g = &fdd_geoms[0];
    for (int i = 0; i < (int) (sizeof(fdd_geoms) / sizeof(fdd_geoms[0])); i++) {
        if (sectors >= fdd_geoms[i].min_sectors) {
            g = &fdd_geoms[i];
            break;
        }
    }

    mgmt_write(0, FMGMT_PRESENT, 0);
    spin(100000);
    mgmt_write(0, FMGMT_CYLS, g->cyls);
    mgmt_write(0, FMGMT_SPT, g->spt);
    mgmt_write(0, FMGMT_TOTAL, g->cyls * g->spt * g->heads);
    mgmt_write(0, FMGMT_HEADS, g->heads);
    mgmt_write(0, FMGMT_WRPROT, 0);
    mgmt_write(0, FMGMT_PRESENT, 1);
}

// Answer one pending controller request. A read pulls the sector from the dataslot
// and streams it to the controller FIFO; a write drains the FIFO and persists it to
// the dataslot. Writes reach the SD file directly, so nothing else is needed here.
void fdd_poll(void)
{
    uint32_t req = *FDD_REQUEST;
    if (req & FDD_REQ_READ) {
        uint32_t lba = mgmt_read(0, FMGMT_PRESENT) & FDD_LBA_MASK;
        pull_sector(FDD0_SLOT_ID, lba);
        push_sector(0);
    } else if (req & FDD_REQ_WRITE) {
        uint32_t lba = mgmt_read(0, FMGMT_PRESENT) & FDD_LBA_MASK;
        pull_fifo(0);
        write_sector(FDD0_SLOT_ID, lba);
    }
}
