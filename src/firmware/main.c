// Disk-service firmware entry point.
//
// Mount each disk image the first time the host reports a non-zero size, then service
// controller requests forever. Every image is optional and may be picked from the
// menu after boot (deferload), so nothing is waited for up front: a machine can boot
// from a floppy, from the hard disk, or from either once its image appears. The heavy
// lifting lives in fdd_service.c and ide_service.c; this is just the top-level loop.

#include "softcpu_regs.h"
#include "vkb_ui.h"

int main(void)
{
    // Start with both hard disks absent so the BIOS boots from floppy until (and
    // unless) an image mounts; this also clears a stale-present state after a reset.
    ide_init();
    vkb_ui_init();

    uint32_t mounted_a = 0;
    uint32_t mounted_b = 0;
    uint32_t mounted_hdd = 0;
    uint32_t mounted_hdd_b = 0;

    for (;;) {
        if (!mounted_a) {
            uint32_t sectors = *FDD0_DISK_SIZE;
            if (sectors != 0) {
                fdd_mount(0, sectors);
                mounted_a = 1;
            }
        }
        if (!mounted_b) {
            uint32_t sectors = *FDD1_DISK_SIZE;
            if (sectors != 0) {
                fdd_mount(1, sectors);
                mounted_b = 1;
            }
        }
        if (!mounted_hdd) {
            uint32_t sectors = *HDD0_DISK_SIZE;
            if (sectors != 0) {
                ide_mount(0, sectors);
                mounted_hdd = 1;
            }
        }
        if (!mounted_hdd_b) {
            uint32_t sectors = *HDD1_DISK_SIZE;
            if (sectors != 0) {
                ide_mount(1, sectors);
                mounted_hdd_b = 1;
            }
        }

        fdd_poll();
        if (mounted_hdd || mounted_hdd_b) {
            ide_poll();
        }
        vkb_ui_tick();
    }

    return 0;
}
