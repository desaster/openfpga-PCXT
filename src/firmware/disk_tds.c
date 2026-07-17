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

// The APF datatable holds two words per slot: word 2k = id, word 2k+1 = size in bytes,
// in data.json declaration order. Return the size word's index for the entry with this
// id, or -1 if the id is not present.
static int dtbl_size_word(uint16_t id)
{
    for (uint32_t k = 0; k < 32; k++) {
        *DTBL_ADDR = 2 * k;
        if ((*DTBL_DATA & 0xFFFF) == id) {
            return (int) (2 * k + 1);
        }
    }
    return -1;
}

// Size in bytes of the slot with this id, or 0 if it is absent or not yet loaded (a
// deferload slot reads 0 until its file lands).
uint32_t slot_bytes(uint16_t id)
{
    int w = dtbl_size_word(id);
    if (w < 0) {
        return 0;
    }
    *DTBL_ADDR = (uint32_t) w;
    return *DTBL_DATA;
}

// Write a slot's size into the datatable so APF flushes a nonvolatile slot whose file
// does not exist yet; it otherwise loads at size 0 and is never written back. Non-zero
// once the entry exists and has been written.
int slot_declare_size(uint16_t id, uint32_t bytes)
{
    int w = dtbl_size_word(id);
    if (w < 0) {
        return 0;
    }
    *DTBL_ADDR = (uint32_t) w;
    *DTBL_DATA = bytes;
    return 1;
}
