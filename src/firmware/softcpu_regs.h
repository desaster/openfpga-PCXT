#ifndef SOFTCPU_REGS_H
#define SOFTCPU_REGS_H

#include <stdint.h>

// Disk-bridge registers (softcpu_fdd_bridge), mapped in the 0x3 region.
#define FDD_REQUEST    ((volatile uint32_t *) 0x30000000) // R: {write, read} pending
#define FDD_MGMT_ADDR  ((volatile uint32_t *) 0x30000004) // W: {drive << 4, reg[3:0]}
#define FDD_MGMT_WDATA ((volatile uint32_t *) 0x30000008) // W: mgmt write data [15:0]
#define FDD_MGMT_TRIG  ((volatile uint32_t *) 0x3000000C) // W: bit0 write, bit1 read
#define FDD_MGMT_RDATA ((volatile uint32_t *) 0x30000010) // R: captured mgmt read data
#define FDD_BRAM_ADDR  ((volatile uint32_t *) 0x30000014) // W: bridge-RAM word address
#define FDD_BRAM_RDATA ((volatile uint32_t *) 0x30000018) // R: bridge-RAM word (auto-inc)
#define FDD_BRAM_WDATA ((volatile uint32_t *) 0x3000001C) // W: bridge-RAM word (auto-inc)
#define FDD_TDS_ID     ((volatile uint32_t *) 0x30000020) // W: dataslot id
#define FDD_TDS_OFFSET ((volatile uint32_t *) 0x30000024) // W: dataslot byte offset
#define FDD_TDS_BRIDGE ((volatile uint32_t *) 0x30000028) // W: bridge address
#define FDD_TDS_LENGTH ((volatile uint32_t *) 0x3000002C) // W: transfer length in bytes
#define FDD_TDS_TRIG   ((volatile uint32_t *) 0x30000030) // W: bit0 read, bit1 write
#define FDD_TDS_STATUS ((volatile uint32_t *) 0x30000034) // R: bit0 done, bits[3:1] err
#define FDD_TDS_CLR    ((volatile uint32_t *) 0x30000038) // W: bit0 clear done
#define FDD0_DISK_SIZE ((volatile uint32_t *) 0x3000003C) // R: floppy-0 image size in sectors
#define FDD1_DISK_SIZE ((volatile uint32_t *) 0x30000040) // R: floppy-1 image size in sectors
#define IDE_REQUEST    ((volatile uint32_t *) 0x30000044) // R: ide0 request [2:0]
#define FDD_REBIND     ((volatile uint32_t *) 0x30000050) // R: per-floppy image-rebind toggles
#define DTBL_ADDR      ((volatile uint32_t *) 0x30000054) // W: datatable word index
#define DTBL_DATA      ((volatile uint32_t *) 0x30000058) // R: datatable word at the index; W: write it

// OSD GPU command registers (softcpu_subsystem), mapped in the 0x4 region. Set XY (and WH for
// FILL/OUTLINE) then write the op; poll STATUS between commands.
#define GPU_XY      ((volatile uint32_t *) 0x40000000) // W: {y[15:0], x[15:0]}
#define GPU_WH      ((volatile uint32_t *) 0x40000004) // W: {h[15:0], w[15:0]}
#define GPU_FILL    ((volatile uint32_t *) 0x40000008) // W: color[3:0] -> fill XY/WH rectangle
#define GPU_STATUS  ((volatile uint32_t *) 0x40000010) // R: bit0 = busy
#define GPU_OUTLINE ((volatile uint32_t *) 0x40000014) // W: {round[4], color[3:0]} -> outline rect
#define GPU_CHAR    ((volatile uint32_t *) 0x40000018) // W: {transp,bg[15:12],fg[11:8],char[7:0]}

// GPU_OUTLINE flag: omit the four corner pixels (1px-rounded look).
#define GPU_OUTLINE_ROUND (1u << 4)
// GPU_CHAR flag: draw only the glyph's lit pixels, leaving the background untouched.
#define GPU_CHAR_TRANSP (1u << 16)

// Status / control (0x2 region).
#define CONT1_KEY    ((volatile uint32_t *) 0x20000000) // R: pocket controller-1 buttons
#define VKB_CTRL     ((volatile uint32_t *) 0x20000004) // W: bit0 = OSD overlay shown
#define VKB_KEY      ((volatile uint32_t *) 0x20000008) // W: bit8 = make, bits[7:0] Set-2 code
#define SETTINGS_REG ((volatile uint32_t *) 0x2000000C) // W: {index[12:8], value[7:0]}
#define OSD_ACTION   ((volatile uint32_t *) 0x20000010) // W: bit0 reset, bit1 credits, bit2 video
#define OSD_ORIGIN   ((volatile uint32_t *) 0x20000014) // W: {y[25:16], x[9:0]} framebuffer origin
#define OSD_RASTER   ((volatile uint32_t *) 0x20000018) // R: {h[25:16], w[9:0]} presented raster size

// OSD_ACTION command bits.
#define OSD_ACT_RESET   1u
#define OSD_ACT_CREDITS 2u
#define OSD_ACT_VIDEO   4u

// cont1_key button bits (Analogue Pocket layout).
#define BTN_UP     (1 << 0)
#define BTN_DOWN   (1 << 1)
#define BTN_LEFT   (1 << 2)
#define BTN_RIGHT  (1 << 3)
#define BTN_A      (1 << 4)
#define BTN_B      (1 << 5)
#define BTN_X      (1 << 6)
#define BTN_Y      (1 << 7)
#define BTN_L1     (1 << 8)
#define BTN_R1     (1 << 9)
#define BTN_SELECT (1 << 14)
#define BTN_START  (1 << 15)

// CONT1_KEY carries the Select/Start function config and status flags in its upper bits (the
// low 16 are the buttons): select_fn[19:16], start_fn[23:20], credits[24], osd_open[25],
// coldboot[26].
#define CONT1_SEL_FN(raw)   (((raw) >> 16) & 0xFu)
#define CONT1_START_FN(raw) (((raw) >> 20) & 0xFu)
#define CONT1_CREDITS(raw)  ((raw) & (1u << 24))
#define CONT1_OSD_OPEN(raw) ((raw) & (1u << 25)) // interact "Extra Options" requests the OSD
#define CONT1_COLDBOOT(raw) ((raw) & (1u << 26)) // no reset requested since power-on

// OSD_RASTER field extractors.
#define RASTER_W(raw) ((raw) & 0x3FFu)
#define RASTER_H(raw) (((raw) >> 16) & 0x3FFu)

// Button function ids the softcore routes (derived in core_top from the Select/Start config;
// key options are handled by pocket_keyboard, not here).
#define BTNFN_NONE     0u
#define BTNFN_SETTINGS 1u
#define BTNFN_CREDITS  2u
#define BTNFN_VIDEO    3u

// FDD_REQUEST bits
#define FDD_REQ_READ  (1 << 0)
#define FDD_REQ_WRITE (1 << 1)

// FDD_REBIND bits: one toggle per floppy drive, flipping on each image (re)bind.
#define FDD0_REBIND_BIT (1 << 0)
#define FDD1_REBIND_BIT (1 << 1)

// FDD_MGMT_TRIG bits
#define FDD_MGMT_WR (1 << 0)
#define FDD_MGMT_RD (1 << 1)

// FDD_TDS_TRIG bits
#define FDD_TDS_READ  (1 << 0)
#define FDD_TDS_WRITE (1 << 1)

// FDD_TDS_STATUS bits
#define FDD_TDS_DONE (1 << 0)
#define FDD_TDS_ERR  (7 << 1) // bits[3:1]: non-zero = transfer error

// floppy.v management registers (mgmt_address[3:0]). Register 0 reads back the
// requested LBA ({drive, lba[14:0]}) and is written to set media-present.
#define FMGMT_PRESENT 0x0
#define FMGMT_WRPROT  0x1
#define FMGMT_CYLS    0x2
#define FMGMT_SPT     0x3
#define FMGMT_TOTAL   0x4
#define FMGMT_HEADS   0x5
#define FMGMT_FIFO    0xF

// LBA read from register 0: 15-bit block, bit 15 selects drive B.
#define FDD_LBA_MASK  0x7FFF
#define FDD_LBA_DRIVE 0x8000

// ide.v management registers (mgmt_address[3:0]). IDE_TARGET is a FDD_MGMT_ADDR bit
// that routes the transaction to ide.v (0xF0) instead of floppy.v (0xF2). The
// taskfile (regs 0-5) is packed/unpacked in ide_service.c per ide.v's register map;
// reg 0xF is the 16-bit sector data port (auto-incrementing).
#define IDE_TARGET    (1 << 8) // FDD_MGMT_ADDR bit: select ide.v
#define IMGMT_PRESENT 0x6      // drive present / config register
#define IMGMT_DATA    0xF      // sector data port
#define IDE_DRV0_WE   (1 << 3) // reg 6: commit drive-0 present/hob bits
#define IDE_DRV1_WE   (1 << 7) // reg 6: commit drive-1 present/hob bits
#define IDE_PRESENT   (1 << 0) // reg 6: drive-0 present (drive-1 present is this << 4)

// ATA status byte, placed in the reg-5 high byte and bit-decoded by ide.v. END
// doubles as last_read (stops re-requesting), RDP as fast_read, IRQ pulses the
// guest interrupt.
#define ATA_BSY      0x80
#define ATA_RDY      0x40
#define ATA_RDP      0x20
#define ATA_DSC      0x10
#define ATA_DRQ      0x08
#define ATA_IRQ      0x04
#define ATA_END      0x02
#define ATA_ERR      0x01
#define ATA_ERR_ABRT 0x04 // error register: command aborted

// ide0 request encoding (IDE_REQUEST): reset, new command, data phase, idle.
#define IDE_REQ_RESET 6
#define IDE_REQ_CMD   4
#define IDE_REQ_DATA  5
#define IDE_REQ_IDLE  0

// APF bridge-RAM base and the sector geometry the transfers use.
#define FDD_BRIDGE_BASE 0x60000000
#define SECTOR_BYTES    512
#define SECTOR_WORDS    128

// Bounded spin for disk waits (dataslot transfers and IDE data-phase handshakes) so a
// stalled transfer or a guest that abandons one cannot hang the softcore, which serves
// both disks and draws the OSD. A real wait resolves in well under a millisecond; this
// is a few seconds of margin, never a false trip.
#define DISK_SPIN_LIMIT 4000000u

// Dataslot ids, matching data.json. Floppy sizes arrive via the dataslot event
// (FDD*_DISK_SIZE); HDD and Settings sizes are read from the datatable by id (slot_bytes).
#define FDD0_SLOT_ID     3
#define FDD1_SLOT_ID     4
#define HDD0_SLOT_ID     5
#define HDD1_SLOT_ID     6
#define SETTINGS_SLOT_ID 7
// Bytes to declare for the nonvolatile Settings slot so it flushes on first boot.
#define SETTINGS_SLOT_BYTES 64

// Shared disk-bridge sector transfer (disk_tds.c).
int tds_transfer(uint32_t slot, uint32_t lba, uint32_t dir);

// APF datatable access by slot id (disk_tds.c).
uint32_t slot_bytes(uint16_t id);
int slot_declare_size(uint16_t id, uint32_t bytes);

// Service entry points (fdd_service.c).
void fdd_mount(uint32_t drive, uint32_t sectors);
void fdd_poll(void);

// Service entry points (ide_service.c).
void ide_init(void);
void ide_mount(uint32_t drive, uint32_t sectors);
void ide_poll(void);

#endif
