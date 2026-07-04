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
#define FDD_DISK_SIZE  ((volatile uint32_t *) 0x3000003C) // R: mounted image size in sectors

// FDD_REQUEST bits
#define FDD_REQ_READ  (1 << 0)
#define FDD_REQ_WRITE (1 << 1)

// FDD_MGMT_TRIG bits
#define FDD_MGMT_WR (1 << 0)
#define FDD_MGMT_RD (1 << 1)

// FDD_TDS_TRIG bits
#define FDD_TDS_READ  (1 << 0)
#define FDD_TDS_WRITE (1 << 1)

// FDD_TDS_STATUS bits
#define FDD_TDS_DONE (1 << 0)

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

// APF bridge-RAM base and the sector geometry the transfers use.
#define FDD_BRIDGE_BASE 0x60000000
#define SECTOR_BYTES    512
#define SECTOR_WORDS    128

// Dataslot id of the drive A: image. Must match the floppy slot in data.json
// (and the id core_top latches the image size for).
#define FDD0_SLOT_ID 2

// Service entry points (fdd_service.c).
void fdd_mount(uint32_t sectors);
void fdd_poll(void);

#endif
