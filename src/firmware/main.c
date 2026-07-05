// Disk-service firmware entry point.
//
// Wait for the host to report a mounted drive-A image and set up its geometry, then
// service controller requests forever, mounting drive B if and when its (optional,
// deferred) image appears. The heavy lifting lives in fdd_service.c; this is just
// the top-level sequence.

#include "softcpu_regs.h"

int main(void)
{
    uint32_t sectors;
    while ((sectors = *FDD_DISK_SIZE) == 0) {
    }

    fdd_mount(0, sectors);

    // Drive B is optional and its image may be picked from the menu after boot
    // (deferload), so mount it the first time a non-zero size appears rather than
    // blocking for it at startup.
    uint32_t mounted_b = 0;

    for (;;) {
        if (!mounted_b) {
            uint32_t sectors_b = *FDD1_DISK_SIZE;
            if (sectors_b != 0) {
                fdd_mount(1, sectors_b);
                mounted_b = 1;
            }
        }
        fdd_poll();
    }

    return 0;
}
