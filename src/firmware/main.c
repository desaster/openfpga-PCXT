// Softcore firmware entry point: bring up the peripherals, then loop servicing disk
// requests and settings while the timer interrupt draws the OSD. The disk and OSD work
// lives in fdd_service.c, ide_service.c, and the vkb/settings units.

#include "key_bind.h"
#include "settings_ui.h"
#include "softcpu_regs.h"
#include "vkb_ui.h"

// The OSD runs from a periodic timer interrupt (see irq() and start.S) so blocking disk
// transfers cannot starve it. ~1 ms at the softcore clock (clk_chipset / 6).
#ifndef CHIPSET_HZ
#define CHIPSET_HZ 42954545u
#endif
#define TIMER_PERIOD (CHIPSET_HZ / 6u / 1000u)

extern void timer_start(uint32_t cycles);
extern void irq_mask(uint32_t mask);

// Read a floppy-size register twice and return it only if the samples agree, else 0. The
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
    // Start with both hard disks absent so the BIOS boots from floppy until (and unless)
    // an image mounts.
    ide_init();
    vkb_ui_init();

    // The guest stays held until settings are staged: wait for the dataslot load (settings_load
    // reads it), adopt the saved settings, then release.
    while (!DATASLOTS_READY(*CONT1_KEY))
        ;
    key_bind_init(); // stage the default button map, which settings_load then overrides from the
                     // save
    settings_load();
    *SOFT_GUEST_HOLD = 0;

    // Arm the timer and enable only its interrupt (bit 0); the fault interrupts stay
    // masked so an illegal instruction still traps rather than looping in irq().
    timer_start(TIMER_PERIOD);
    irq_mask(0xFFFFFFFEu);

    // Images are deferload (optional, menu-picked at will), so mount lazily on a drive's
    // first non-zero size, and for a floppy again on each rebind-toggle flip: fdd_mount's
    // eject/insert re-arms floppy.v's media-change line, the only signal a same-size swap
    // gives (hard disks reload the core, so they mount once).
    uint32_t mounted_a = 0;
    uint32_t mounted_b = 0;
    uint32_t mounted_hdd = 0;
    uint32_t mounted_hdd_b = 0;
    uint32_t settings_sized = 0;        // Settings size declared in the datatable yet
    uint32_t rebind_seen = *FDD_REBIND; // last-seen rebind toggles

    for (;;) {
        // Declare the Settings size once the datatable is populated (retried because the
        // softcore may run before the host has written the table).
        if (!settings_sized) {
            settings_sized = slot_declare_size(SETTINGS_SLOT_ID, SETTINGS_SLOT_BYTES);
        }

        uint32_t rebind = *FDD_REBIND;
        if (!mounted_a || ((rebind ^ rebind_seen) & FDD0_REBIND_BIT)) {
            uint32_t sectors = stable_size(FDD0_DISK_SIZE);
            if (sectors != 0) {
                fdd_mount(0, sectors);
                mounted_a = 1;
            }
        }
        if (!mounted_b || ((rebind ^ rebind_seen) & FDD1_REBIND_BIT)) {
            uint32_t sectors = stable_size(FDD1_DISK_SIZE);
            if (sectors != 0) {
                fdd_mount(1, sectors);
                mounted_b = 1;
            }
        }
        rebind_seen = rebind;
        if (!mounted_hdd) {
            uint32_t sectors = slot_bytes(HDD0_SLOT_ID) / SECTOR_BYTES;
            if (sectors != 0) {
                ide_mount(0, sectors);
                mounted_hdd = 1;
            }
        }
        if (!mounted_hdd_b) {
            uint32_t sectors = slot_bytes(HDD1_SLOT_ID) / SECTOR_BYTES;
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
