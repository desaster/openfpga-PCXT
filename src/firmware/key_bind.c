#include "key_bind.h"

#include "softcpu_regs.h"

// Per-button encoding: 0 = unmapped, a Set-2 make code (E0 flag in the ext bitmap), or an OSD
// function 0xF1..0xF3 (BTNFN_* + 0xF0). Real make codes top out at 0xE2 (hid_to_ps2), so they never
// reach the function range; RTL only ever receives the resolved key (0 for a function).
#define BIND_FN_FIRST 0xF1u

// key_cfg slot per button, matching pocket_keyboard's scan index (btn_idx): A/B/X/Y are 4-7,
// Select/Start 8-9, R1 10. The D-pad (0-3) and diagonals (11-14) are filled elsewhere.
static const uint8_t bind_keycfg_id[BIND_COUNT] = { 4, 5, 6, 7, 10, 8, 9 };

// Default bindings: A=L-Ctrl, B=L-Alt, X=Space, Y=Enter, R1 unmapped, Select=Settings,
// Start=Pause/Credits. All single-byte, so the ext bitmap defaults clear.
static const uint8_t bind_default[BIND_COUNT] = { 0x14, 0x11, 0x29, 0x5A, 0x00, 0xF1, 0xF2 };
static uint8_t bind[BIND_COUNT];
static uint8_t bind_ext;

static void push(int btn)
{
    uint8_t code = bind[btn];
    uint8_t key = (code >= BIND_FN_FIRST) ? 0u : code; // a function types nothing
    uint8_t ext = (uint8_t) ((bind_ext >> btn) & 1u);
    *KEYCFG_REG = ((uint32_t) bind_keycfg_id[btn] << 9) | ((uint32_t) ext << 8) | key;
}

void key_bind_init(void)
{
    key_bind_reset();
}

void key_bind_reset(void)
{
    bind_ext = 0;
    for (int b = 0; b < BIND_COUNT; b++) {
        bind[b] = bind_default[b];
        push(b);
    }
}

void key_bind_set(int btn, uint8_t code, int ext)
{
    bind[btn] = code;
    if (ext) {
        bind_ext |= (uint8_t) (1u << btn);
    } else {
        bind_ext &= (uint8_t) ~(1u << btn);
    }
    push(btn);
}

uint8_t key_bind_code(int btn)
{
    return bind[btn];
}

int key_bind_ext(int btn)
{
    return (bind_ext >> btn) & 1;
}

uint8_t key_bind_function(int btn)
{
    uint8_t code = bind[btn];
    return (code >= BIND_FN_FIRST) ? (uint8_t) (code - 0xF0u) : 0u;
}
