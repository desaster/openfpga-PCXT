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
#define FDD_TDS_TRIG   ((volatile uint32_t *) 0x30000030) // W: bit0 read, bit1 write, bit2 flush
#define FDD_TDS_STATUS ((volatile uint32_t *) 0x30000034) // R: bit0 done, bits[3:1] err
#define FDD_TDS_CLR    ((volatile uint32_t *) 0x30000038) // W: bit0 clear done
#define FDD0_DISK_SIZE ((volatile uint32_t *) 0x3000003C) // R: floppy-0 image size in sectors
#define FDD1_DISK_SIZE ((volatile uint32_t *) 0x30000040) // R: floppy-1 image size in sectors
#define IDE_REQUEST    ((volatile uint32_t *) 0x30000044) // R: ide0 request [2:0]
#define HDD0_DISK_SIZE ((volatile uint32_t *) 0x30000048) // R: hard-disk-0 image size in sectors
#define HDD1_DISK_SIZE ((volatile uint32_t *) 0x3000004C) // R: hard-disk-1 image size in sectors

// OSD framebuffer (softcpu_subsystem), 636x81 at 4bpp, mapped in the 0x4 region.
#define OSD_FB ((uint8_t *) 0x40000000)

// Status / control (0x2 region).
#define CONT1_KEY ((volatile uint32_t *) 0x20000000) // R: pocket controller-1 buttons
#define VKB_CTRL  ((volatile uint32_t *) 0x20000004) // W: bit0 = OSD shown, bit1 = OSD at top
#define VKB_KEY   ((volatile uint32_t *) 0x20000008) // W: bit8 = make, bits[7:0] Set-2 code

// cont1_key button bits (Analogue Pocket layout).
#define BTN_UP    (1 << 0)
#define BTN_DOWN  (1 << 1)
#define BTN_LEFT  (1 << 2)
#define BTN_RIGHT (1 << 3)
#define BTN_A     (1 << 4)
#define BTN_B     (1 << 5)
#define BTN_X     (1 << 6)
#define BTN_Y     (1 << 7)
#define BTN_L1    (1 << 8)
#define BTN_R1    (1 << 9)

// FDD_REQUEST bits
#define FDD_REQ_READ  (1 << 0)
#define FDD_REQ_WRITE (1 << 1)

// FDD_MGMT_TRIG bits
#define FDD_MGMT_WR (1 << 0)
#define FDD_MGMT_RD (1 << 1)

// FDD_TDS_TRIG bits
#define FDD_TDS_READ  (1 << 0)
#define FDD_TDS_WRITE (1 << 1)
#define FDD_TDS_FLUSH (1 << 2)

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

// Dataslot ids of the floppy and hard-disk images. Must match the slots in
// data.json (and the ids core_top latches the image sizes for).
#define FDD0_SLOT_ID 2
#define FDD1_SLOT_ID 3
#define HDD0_SLOT_ID 4
#define HDD1_SLOT_ID 5

// Shared disk-bridge sector transfer (disk_tds.c).
int tds_transfer(uint32_t slot, uint32_t lba, uint32_t dir);

// Service entry points (fdd_service.c).
void fdd_mount(uint32_t drive, uint32_t sectors);
void fdd_poll(void);

// Service entry points (ide_service.c).
void ide_init(void);
void ide_mount(uint32_t drive, uint32_t sectors);
void ide_poll(void);

#endif
