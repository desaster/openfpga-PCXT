// Disk-service firmware entry point.
//
// Wait for the host to report a mounted drive-A image, set up its geometry once,
// then service controller requests forever. The heavy lifting lives in
// fdd_service.c; this is just the top-level sequence.

#include "softcpu_regs.h"

int main(void)
{
    uint32_t sectors;
    while ((sectors = *FDD_DISK_SIZE) == 0) {
    }

    fdd_mount(sectors);

    for (;;) {
        fdd_poll();
    }

    return 0;
}
