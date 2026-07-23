#include "dpad.h"

#include "softcpu_regs.h"

typedef struct {
    uint8_t ext;
    uint8_t code;
} keydef_t;

// Cardinal keys per preset, in key_cfg id order: 0=up(N) 1=down(S) 2=left(W) 3=right(E).
static const keydef_t dpad_cardinal[DPAD_COUNT][4] = {
    { { 0, 0x75 }, { 0, 0x72 }, { 0, 0x6B }, { 0, 0x74 } }, // Numpad: keypad 8/2/4/6
    { { 0, 0x75 }, { 0, 0x72 }, { 0, 0x6B }, { 0, 0x74 } }, // Numpad w/ Diag.
    { { 1, 0x75 }, { 1, 0x72 }, { 1, 0x6B }, { 1, 0x74 } }, // Arrows: E0 cursor keys
    { { 0, 0x1D }, { 0, 0x1B }, { 0, 0x1C }, { 0, 0x23 } }, // WASD
    { { 0, 0x42 }, { 0, 0x3B }, { 0, 0x33 }, { 0, 0x4B } }, // HJKL: K/J/H/L
    { { 0, 0x42 }, { 0, 0x3B }, { 0, 0x33 }, { 0, 0x4B } }, // HJKL w/ YUBN
};

// Corner keys per preset, in key_cfg id order: 11=NW 12=NE 13=SW 14=SE. Only the two "w/ diag."
// presets define them; a zero corner keeps the D-pad in cardinal mode, so switching back to a
// cardinal preset clears the hat.
static const keydef_t dpad_corner[DPAD_COUNT][4] = {
    { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },             // Numpad
    { { 0, 0x6C }, { 0, 0x7D }, { 0, 0x69 }, { 0, 0x7A } }, // Numpad w/ Diag.: keypad 7/9/1/3
    { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },             // Arrows
    { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },             // WASD
    { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },             // HJKL
    { { 0, 0x35 }, { 0, 0x3C }, { 0, 0x32 }, { 0, 0x31 } }, // HJKL w/ YUBN: y/u/b/n
};

void dpad_apply(int preset)
{
    if (preset < 0 || preset >= DPAD_COUNT) {
        preset = DPAD_NUMPAD;
    }
    for (int d = 0; d < 4; d++) {
        const keydef_t *c = &dpad_cardinal[preset][d];
        *KEYCFG_REG = ((uint32_t) d << 9) | ((uint32_t) c->ext << 8) | c->code;
        const keydef_t *k = &dpad_corner[preset][d];
        *KEYCFG_REG = ((uint32_t) (11 + d) << 9) | ((uint32_t) k->ext << 8) | k->code;
    }
}
