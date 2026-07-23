#include "dpad.h"

#include "softcpu_regs.h"

typedef struct {
    uint8_t ext;
    uint8_t code;
} keydef_t;

// Cardinal keys per preset, in key_cfg id order: 0=up(N) 1=down(S) 2=left(W) 3=right(E). The two
// "w/ diag." presets share their base cardinals here; their corner keys arrive with the resolver.
static const keydef_t dpad_cardinal[DPAD_COUNT][4] = {
    { { 0, 0x75 }, { 0, 0x72 }, { 0, 0x6B }, { 0, 0x74 } }, // Numpad: keypad 8/2/4/6
    { { 0, 0x75 }, { 0, 0x72 }, { 0, 0x6B }, { 0, 0x74 } }, // Numpad w/ Diag.
    { { 1, 0x75 }, { 1, 0x72 }, { 1, 0x6B }, { 1, 0x74 } }, // Arrows: E0 cursor keys
    { { 0, 0x1D }, { 0, 0x1B }, { 0, 0x1C }, { 0, 0x23 } }, // WASD
    { { 0, 0x42 }, { 0, 0x3B }, { 0, 0x33 }, { 0, 0x4B } }, // HJKL: K/J/H/L
    { { 0, 0x42 }, { 0, 0x3B }, { 0, 0x33 }, { 0, 0x4B } }, // HJKL w/ YUBN
};

void dpad_apply(int preset)
{
    if (preset < 0 || preset >= DPAD_COUNT) {
        preset = DPAD_NUMPAD;
    }
    for (int d = 0; d < 4; d++) {
        const keydef_t *k = &dpad_cardinal[preset][d];
        *KEYCFG_REG = ((uint32_t) d << 9) | ((uint32_t) k->ext << 8) | k->code;
    }
}
