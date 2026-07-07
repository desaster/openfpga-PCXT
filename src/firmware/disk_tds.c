// Shared target-dataslot sector transfer for the floppy and IDE services.

#include "softcpu_regs.h"

// Move one 512-byte sector between an image dataslot and the bridge RAM (dir =
// FDD_TDS_READ or FDD_TDS_WRITE) and wait for it. Bounded so a stalled transfer cannot
// hang the softcore, which serves both disks and the OSD. Non-zero on success, zero on
// timeout or a transfer error.
int tds_transfer(uint32_t slot, uint32_t lba, uint32_t dir)
{
    *FDD_TDS_ID = slot;
    *FDD_TDS_OFFSET = lba * SECTOR_BYTES;
    *FDD_TDS_BRIDGE = FDD_BRIDGE_BASE;
    *FDD_TDS_LENGTH = SECTOR_BYTES;
    *FDD_TDS_CLR = 1;
    *FDD_TDS_TRIG = dir;
    uint32_t to = DISK_SPIN_LIMIT;
    uint32_t st;
    while (!((st = *FDD_TDS_STATUS) & FDD_TDS_DONE) && --to) {
    }
    return to != 0 && !(st & FDD_TDS_ERR);
}
