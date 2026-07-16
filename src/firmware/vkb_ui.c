#include "settings_ui.h"
#include "softcpu_regs.h"
#include "vkb_draw.h"
#include "vkb_layout.h"
#include "vkb_ui.h"

// D-pad auto-repeat timing, in cycles (the softcore runs at clk_chipset / 6).
#ifndef CHIPSET_HZ
#define CHIPSET_HZ 42954545u
#endif
#define CLK_FREQ      (CHIPSET_HZ / 6u)
#define REPEAT_DELAY  (CLK_FREQ / 2)  // hold this long before the cursor repeats
#define REPEAT_RATE   (CLK_FREQ / 10) // then step at ~10 Hz
#define MOVE_COOLDOWN (CLK_FREQ / 25) // debounce between moves
#define BTN_DPAD      (BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)

// The 636x81 keyboard sits flush against the bottom (or top) edge of the 640x200
// framebuffer; the position toggle just redraws it at the other origin.
#define VKB_X 2

// KFPS2KB accepts one Set-2 byte per ~0.88 ms (1136/s); a break is two bytes. Emitting
// a burst of breaks (clearing many latches at once) faster than that overflows
// pocket_keyboard's event queue and drops keys, leaving them stuck down. Pace each break
// by two byte-times; keep this in step with KFPS2KB's inter-byte PACE.
#define PS2_BREAK_CYCLES (2u * CLK_FREQ / 1136u)

static inline uint32_t rdcycle(void)
{
    uint32_t c;
    __asm__ volatile("rdcycle %0" : "=r"(c));
    return c;
}

// Which overlay is on screen; the two are mutually exclusive and drawn on demand.
enum { OSD_NONE = 0, OSD_VKB, OSD_SETTINGS };

static osd_fb_t osd;
static uint16_t ui_prev;          // previous button state, for edge detection
static uint8_t ui_mode;           // OSD_NONE / OSD_VKB / OSD_SETTINGS
static uint8_t credits_shown;     // credits overlay up (latches core_top's flag across the dismiss)
static uint8_t osd_open_prev;     // previous interact "Extra Options" request, for edge detection
static uint8_t ui_osd_top;        // VKB at the top of the screen instead of the bottom
static uint32_t ui_raster;        // presented raster size, {h[25:16], w[9:0]}
static int cur_key;               // selected key index
static int cur_vrow;              // selected visual row
static int held_key;              // key momentarily held by button A, -1 = none
static uint32_t latch_bits[3];    // one bit per key index: latched keys stay down
static uint32_t ui_repeat_timer;  // cycle deadline for the next auto-repeat
static uint16_t ui_repeat_btn;    // dpad direction(s) held for repeat
static uint32_t ui_move_cooldown; // cycle deadline suppressing the next move

// Push one make/break event to pocket_keyboard's event queue. The register
// strobe toggles per write, so each call is exactly one queued key event.
static void vkb_emit(int make, uint8_t scancode)
{
    *VKB_KEY = ((uint32_t) (make ? 1 : 0) << 8) | scancode;
}

// Compositor origin: where the framebuffer's top-left lands on the presented raster
// (assumed at least framebuffer-sized). Centred, except the keyboard's edge-hugging
// layout stays aligned to the raster's top or bottom edge.
static void osd_origin_write(void)
{
    uint32_t w = RASTER_W(ui_raster);
    uint32_t h = RASTER_H(ui_raster);
    uint32_t x = (w - OSD_FB_WIDTH) / 2;
    uint32_t y;
    if (ui_mode == OSD_VKB) {
        y = ui_osd_top ? 0 : (h - OSD_FB_HEIGHT);
    } else {
        y = (h - OSD_FB_HEIGHT) / 2;
    }
    *OSD_ORIGIN = (y << 16) | x;
}

// OSD control word: bit0 = an overlay is shown; the origin is refreshed first.
static void osd_ctrl_write(void)
{
    osd_origin_write();
    *VKB_CTRL = (ui_mode != OSD_NONE) ? 1u : 0u;
}

static int is_latched(int i)
{
    return (latch_bits[i >> 5] >> (i & 31)) & 1u;
}

static void set_latched(int i, int on)
{
    uint32_t m = 1u << (i & 31);
    if (on) {
        latch_bits[i >> 5] |= m;
    } else {
        latch_bits[i >> 5] &= ~m;
    }
}

// Border colour for a key, given whether it is the cursor and whether it is latched.
static uint8_t key_color(int i)
{
    if (i == cur_key) {
        return is_latched(i) ? OSD_LATCH_CUR : OSD_CURSOR;
    }
    return is_latched(i) ? OSD_LATCH : OSD_KEYEDGE;
}

// Visual rows for navigation: each is a contiguous, left-to-right span of
// vkb_keys[] (function block + main block + keypad).
static const struct {
    uint8_t start, count;
} vrows[] = {
    { 0, 18 },  // row 0
    { 18, 20 }, // row 1
    { 38, 19 }, // row 2
    { 57, 19 }, // row 3
    { 76, 7 },  // row 4
};
#define NUM_VROWS 5

// Vertical steps to the adjacent row and picks the key whose horizontal centre is
// nearest (so staggered rows never skip); horizontal steps by index within the
// current row. Both wrap.
static void cursor_move(int dx, int dy)
{
    vkb_key_border(&osd, cur_key, is_latched(cur_key) ? OSD_LATCH : OSD_KEYEDGE);

    if (dy) {
        int new_vrow = cur_vrow + dy;
        if (new_vrow < 0) {
            new_vrow = NUM_VROWS - 1;
        }
        if (new_vrow >= NUM_VROWS) {
            new_vrow = 0;
        }
        int cur_cx = vkb_keys[cur_key].x + vkb_keys[cur_key].w / 2;
        int best = vrows[new_vrow].start;
        int best_dist = 9999;
        for (int i = 0; i < vrows[new_vrow].count; i++) {
            int ki = vrows[new_vrow].start + i;
            int kx = vkb_keys[ki].x + vkb_keys[ki].w / 2;
            int dist = cur_cx - kx;
            if (dist < 0) {
                dist = -dist;
            }
            // On ties, prefer the rightward key when moving down.
            if (dist < best_dist || (dist == best_dist && dy > 0)) {
                best_dist = dist;
                best = ki;
            }
        }
        cur_key = best;
        cur_vrow = new_vrow;
    }

    if (dx) {
        int count = vrows[cur_vrow].count;
        int vcol = (cur_key - vrows[cur_vrow].start) + dx;
        if (vcol < 0) {
            vcol = count - 1;
        }
        if (vcol >= count) {
            vcol = 0;
        }
        cur_key = vrows[cur_vrow].start + vcol;
    }

    vkb_key_border(&osd, cur_key, key_color(cur_key));
}

void vkb_ui_init(void)
{
    osd.x0 = VKB_X;
    osd.width = vkb_width_px();
    osd.height = vkb_height_px();
    cur_key = 0;
    cur_vrow = 0;
    held_key = -1;
    ui_osd_top = 0;
    ui_raster = *OSD_RASTER;
    osd.y0 = ui_osd_top ? 0 : (OSD_FB_HEIGHT - osd.height);
    latch_bits[0] = latch_bits[1] = latch_bits[2] = 0;
    ui_mode = OSD_NONE; // nothing is shown until an overlay is opened
}

// Busy-wait one break (two byte-times) so a batch of breaks cannot outpace KFPS2KB's
// byte rate and overflow pocket_keyboard's queue (see PS2_BREAK_CYCLES).
static void vkb_pace_break(void)
{
    uint32_t deadline = rdcycle() + PS2_BREAK_CYCLES;
    while ((int32_t) (rdcycle() - deadline) < 0) {
    }
}

// Break every latched key and repaint it to its resting colour (button Y, and part
// of closing). Breaks are paced so clearing a large batch cannot overflow the output.
static void vkb_clear_latches(void)
{
    for (int i = 0; i < vkb_key_count; i++) {
        if (is_latched(i)) {
            vkb_emit(0, vkb_keys[i].scancode);
            set_latched(i, 0);
            vkb_key_border(&osd, i, (i == cur_key) ? OSD_CURSOR : OSD_KEYEDGE);
            vkb_pace_break();
        }
    }
}

// Release everything held (latched + momentary) so no key stays down after closing.
static void vkb_release_all(void)
{
    vkb_clear_latches();
    if (held_key >= 0) {
        vkb_emit(0, vkb_keys[held_key].scancode);
        held_key = -1;
    }
}

// Force the settings OSD open from any mode; used by the Select button and the interact opener.
static void osd_enter_settings(void)
{
    vkb_release_all(); // drop any held keyboard keys before switching overlays
    ui_mode = OSD_SETTINGS;
    settings_open();
    osd_ctrl_write();
}

// Run a Select/Start button's configured OSD function. Key-mapped buttons carry fn = None and
// type through pocket_keyboard instead.
static void button_function(uint8_t fn)
{
    switch (fn) {
    case BTNFN_SETTINGS:
        if (ui_mode == OSD_SETTINGS) {
            ui_mode = OSD_NONE;
            osd_ctrl_write();
        } else {
            osd_enter_settings();
        }
        break;
    case BTNFN_CREDITS:
        vkb_release_all();
        ui_mode = OSD_NONE; // close any overlay so the credits scroll shows on a clean screen
        osd_ctrl_write();
        settings_show_credits();
        break;
    case BTNFN_VIDEO:
        *OSD_ACTION = 0;             // re-arm the edge
        *OSD_ACTION = OSD_ACT_VIDEO; // rising edge -> toggle the displayed video card
        break;
    default: // BTNFN_NONE
        break;
    }
}

// Keyboard-mode input: navigation and the key buttons. Nonzero when the user closed
// the keyboard (button B), mirroring settings_input's contract.
static int vkb_input(uint16_t pressed, uint16_t buttons)
{
    if (pressed & BTN_B) { // close the keyboard
        vkb_release_all();
        return 1;
    }
    if (pressed & BTN_R1) { // swap the OSD between bottom and top, redrawing at the new spot
        ui_osd_top = !ui_osd_top;
        osd.y0 = ui_osd_top ? 0 : (OSD_FB_HEIGHT - osd.height);
        osd_origin_write();
        vkb_draw_keyboard(&osd, cur_key);
    }
    // D-pad: a fresh press moves once; holding past REPEAT_DELAY repeats at
    // REPEAT_RATE. A short cooldown debounces each move; diagonals resolve to
    // vertical.
    uint16_t dpad_ev = pressed & BTN_DPAD;
    uint32_t now = rdcycle();
    ui_repeat_btn &= buttons; // drop any direction no longer held (stale-repeat guard)
    if (buttons & BTN_DPAD) {
        if (pressed & BTN_DPAD) {
            ui_repeat_btn = buttons & BTN_DPAD;
            ui_repeat_timer = now + REPEAT_DELAY;
            if ((int32_t) (now - ui_move_cooldown) < 0) {
                dpad_ev = 0;
            }
        } else if ((int32_t) (now - ui_repeat_timer) >= 0) {
            dpad_ev |= ui_repeat_btn;
            ui_repeat_timer = now + REPEAT_RATE;
        }
    } else {
        ui_repeat_btn = 0;
        ui_move_cooldown = now;
    }
    if ((dpad_ev & (BTN_UP | BTN_DOWN)) && (dpad_ev & (BTN_LEFT | BTN_RIGHT))) {
        dpad_ev &= BTN_UP | BTN_DOWN;
    }
    if (dpad_ev & BTN_UP) {
        cursor_move(0, -1);
    }
    if (dpad_ev & BTN_DOWN) {
        cursor_move(0, 1);
    }
    if (dpad_ev & BTN_LEFT) {
        cursor_move(-1, 0);
    }
    if (dpad_ev & BTN_RIGHT) {
        cursor_move(1, 0);
    }
    if (dpad_ev) {
        ui_move_cooldown = now + MOVE_COOLDOWN;
    }
    if (pressed & BTN_X) { // latch/unlatch (hold modifiers for chords)
        int on = !is_latched(cur_key);
        set_latched(cur_key, on);
        vkb_emit(on, vkb_keys[cur_key].scancode);
        vkb_key_border(&osd, cur_key, key_color(cur_key));
    }
    if (pressed & BTN_Y) { // clear every latched key
        vkb_clear_latches();
    }
    // A momentarily presses a non-latched key; typematic then repeats it while held.
    if ((pressed & BTN_A) && !is_latched(cur_key)) {
        vkb_emit(1, vkb_keys[cur_key].scancode);
        held_key = cur_key;
    }
    return 0;
}

void vkb_ui_tick(void)
{
    uint32_t raw = *CONT1_KEY;
    uint16_t buttons = raw & 0xFFFF;

    // A raster-size change (the displayed card switched) re-bases any overlay on screen.
    uint32_t raster = *OSD_RASTER;
    if (raster != ui_raster) {
        ui_raster = raster;
        osd_origin_write();
    }

    // While the credits overlay is up, any button dismisses it (core_top does that); swallow input
    // here so the dismissing press doesn't also run a button function or re-trigger credits.
    // credits_shown latches the flag so the press is caught even as core_top clears it the same
    // tick.
    if (credits_shown || CONT1_CREDITS(raw)) {
        credits_shown = CONT1_CREDITS(raw) != 0;
        ui_prev = buttons;
        return;
    }

    // The interact "Extra Options" action force-opens the settings OSD, edge-detected so closing it
    // within the request window doesn't reopen. The guaranteed opener regardless of Button Select.
    uint8_t osd_open = CONT1_OSD_OPEN(raw) != 0;
    if (osd_open && !osd_open_prev) {
        osd_enter_settings();
    }
    osd_open_prev = osd_open;

    uint16_t pressed = buttons & ~ui_prev;
    uint16_t released = ~buttons & ui_prev;
    ui_prev = buttons;

    // L1 toggles the keyboard; Select/Start run their configured OSD function (Settings or credits
    // by default). When mapped to a key instead, fn is None and pocket_keyboard types the key.
    if (pressed & BTN_L1) {
        if (ui_mode == OSD_VKB) {
            vkb_release_all(); // nothing stays down after closing
            ui_mode = OSD_NONE;
        } else {
            ui_mode = OSD_VKB;
            vkb_draw_keyboard(&osd, cur_key);
        }
        osd_ctrl_write();
    }
    if (pressed & BTN_SELECT) {
        button_function(CONT1_SEL_FN(raw));
    }
    if (pressed & BTN_START) {
        button_function(CONT1_START_FN(raw));
    }

    // Release the momentary key when A is let go, so its make is matched by a break.
    if (held_key >= 0 && (released & BTN_A)) {
        vkb_emit(0, vkb_keys[held_key].scancode);
        held_key = -1;
    }

    if (ui_mode == OSD_SETTINGS) {
        if (settings_input(pressed)) { // nonzero = user dismissed the overlay
            ui_mode = OSD_NONE;
            osd_ctrl_write();
        }
        return;
    }

    // Navigation and the key buttons are suspended while a momentary key is held:
    // a make/break scancode key cannot be momentary and latched at once, so the two
    // are kept apart.
    if (ui_mode == OSD_VKB && held_key < 0) {
        if (vkb_input(pressed, buttons)) { // nonzero = user closed the keyboard
            ui_mode = OSD_NONE;
            osd_ctrl_write();
        }
    }
}
