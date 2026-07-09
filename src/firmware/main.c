// Disk-service firmware entry point.
//
// Mount each disk image the first time the host reports a non-zero size, then service
// controller requests forever. Every image is optional and may be picked from the
// menu after boot (deferload), so nothing is waited for up front: a machine can boot
// from a floppy, from the hard disk, or from either once its image appears. The heavy
// lifting lives in fdd_service.c and ide_service.c; this is just the top-level loop.

#include "settings_ui.h"
#include "softcpu_regs.h"
#include "vkb_ui.h"

// The OSD runs from a periodic timer interrupt (see irq() and start.S) so blocking disk
// transfers cannot starve it. ~1 ms at the 8.33 MHz softcore clock.
#define TIMER_PERIOD 8333u

extern void timer_start(uint32_t cycles);
extern void irq_mask(uint32_t mask);

// Read a disk-size register twice and return it only if the samples agree, else 0. The
// size crosses clock domains per-bit and can tear as it changes from 0 to the image size;
// two matching reads reject a half-updated value, and the caller retries on the next poll.
static uint32_t stable_size(volatile uint32_t *reg)
{
    uint32_t a = *reg;
    uint32_t b = *reg;
    return (a == b) ? a : 0;
}

int main(void)
{
    // Start with both hard disks absent so the BIOS boots from floppy until (and
    // unless) an image mounts; this also clears a stale-present state after a reset.
    ide_init();
    vkb_ui_init();
    settings_load(); // adopt persisted settings before the timer IRQ can draw the OSD

    // Arm the timer and enable only its interrupt (bit 0); the fault interrupts stay
    // masked so an illegal instruction still traps rather than looping in irq().
    timer_start(TIMER_PERIOD);
    irq_mask(0xFFFFFFFEu);

    uint32_t mounted_a = 0;
    uint32_t mounted_b = 0;
    uint32_t mounted_hdd = 0;
    uint32_t mounted_hdd_b = 0;

    for (;;) {
        if (!mounted_a) {
            uint32_t sectors = stable_size(FDD0_DISK_SIZE);
            if (sectors != 0) {
                fdd_mount(0, sectors);
                mounted_a = 1;
            }
        }
        if (!mounted_b) {
            uint32_t sectors = stable_size(FDD1_DISK_SIZE);
            if (sectors != 0) {
                fdd_mount(1, sectors);
                mounted_b = 1;
            }
        }
        if (!mounted_hdd) {
            uint32_t sectors = stable_size(HDD0_DISK_SIZE);
            if (sectors != 0) {
                ide_mount(0, sectors);
                mounted_hdd = 1;
            }
        }
        if (!mounted_hdd_b) {
            uint32_t sectors = stable_size(HDD1_DISK_SIZE);
            if (sectors != 0) {
                ide_mount(1, sectors);
                mounted_hdd_b = 1;
            }
        }

        fdd_poll();
        if (mounted_hdd || mounted_hdd_b) {
            ide_poll();
        }
        settings_service(); // persist any OSD changes into the save window
    }

    return 0;
}

// Timer interrupt handler: re-arm the timer, service the OSD, and return the saved
// context unchanged.
uint32_t *irq(uint32_t *regs, uint32_t irq_bits)
{
    (void) irq_bits;
    timer_start(TIMER_PERIOD);
    vkb_ui_tick();
    return regs;
}
