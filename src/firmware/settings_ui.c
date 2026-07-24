#include "settings_ui.h"

#include "dpad.h"
#include "key_bind.h"
#include "softcpu_regs.h"
#include "vkb_draw.h"
#include "vkb_layout.h"
#include "vkb_ui.h"

// The settings overlay: a CP437-framed panel of submenus, drawn on demand into the shared OSD
// framebuffer and navigated with the D-pad. Each edit updates the value in RAM and pushes it to the
// softcore settings register that drives the machine.

// Panel geometry in 8px character cells, centred in the framebuffer. The last content row before
// the bottom border carries the control hint.
#define PANEL_COLS 44
#define PANEL_ROWS 15
#define PANEL_W    (PANEL_COLS * 8)
#define PANEL_H    (PANEL_ROWS * 8)
#define PANEL_X    ((OSD_FB_WIDTH - PANEL_W) / 2)
#define PANEL_Y    ((OSD_FB_HEIGHT - PANEL_H) / 2)

// Content cells within the frame.
#define ROW_TITLE  1
#define ROW_FIRST  3 // first menu-item row
#define COL_TITLE  2
#define COL_CURSOR 2
#define COL_LABEL  4
#define COL_VALUE  24

// CP437 box-drawing frame and the right-pointing cursor / submenu marker.
#define G_TL     0xDA
#define G_TR     0xBF
#define G_BL     0xC0
#define G_BR     0xD9
#define G_HORIZ  0xC4
#define G_VERT   0xB3
#define G_MARKER 0x10

static const osd_fb_t panel = { PANEL_X, PANEL_Y, PANEL_W, PANEL_H };

// Every option-valued setting, addressed by id. `value` is the current selection (an index into
// `opts`); it starts at the first option here, and the option order/default is reconciled with the
// machine when each setting is wired.
enum {
    // System
    SET_CPU_SPEED,
    SET_CGA_GFX,
    SET_HGC_GFX,
    SET_VIDEO_1ST,
    SET_BIOS_WR,
    SET_SPLASH,
    // Audio & Video
    SET_OPL2,
    SET_BOOST,
    SET_SPK_VOL,
    SET_STEREO,
    SET_CMS,
    SET_COMPOSITE,
    SET_DISPLAY,
    // Hardware
    SET_EMS,
    SET_EMS_FRAME,
    SET_A000,
    SET_JOY1,
    SET_JOY2,
    SET_SWAPJOY,
    SET_SYNCJOY,
    // Controls
    SET_DPAD,
    SET_GAMEPAD,
    SET_COUNT // new settings append above: the save blob stores values by index
};

static const char *const opt_cpu[] = { "4.77 MHz", "7.16 MHz", "9.54 MHz", "PC/AT 3.5 MHz" };
static const char *const opt_bios_wr[] = { "None", "EC00", "Main", "All" };
static const char *const opt_opl2[] = { "Adlib 388h", "SB FM 388h/228h", "Disabled" };
static const char *const opt_boost[] = { "None", "2x", "4x" };
static const char *const opt_level4[] = { "1", "2", "3", "4" };
static const char *const opt_stereo[] = { "None", "25%", "50%", "100%" };
static const char *const opt_off_on[] = { "Off", "On" };
static const char *const opt_dis_en[] = { "Disabled", "Enabled" };
static const char *const opt_display[] = { "Full Color", "Green", "Amber", "B&W", "Red", "Blue",
    "Fuchsia", "Purple" };
static const char *const opt_ems_frame[] = { "C000", "D000", "E000" };
static const char *const opt_joy[] = { "Analog", "Digital", "Disabled" };
static const char *const opt_no_yes[] = { "No", "Yes" };
static const char *const opt_yes_no[] = { "Yes", "No" };
static const char *const opt_video_1st[] = { "CGA", "Hercules" };
static const char *const opt_dpad[] = { "Numpad", "Numpad w/ Diag.", "Arrows", "WASD", "HJKL",
    "HJKL w/ YUBN" };
static const char *const opt_gamepad[] = { "Keyboard", "Joystick", "Mouse" };

typedef struct {
    const char *const *opts;
    uint8_t count;
    uint8_t value;
} setting_t;

#define SETTING(a)      { (a), (uint8_t) (sizeof(a) / sizeof((a)[0])), 0 }
#define SETTING_D(a, d) { (a), (uint8_t) (sizeof(a) / sizeof((a)[0])), (d) }

static setting_t settings[SET_COUNT] = {
    SETTING(opt_cpu),         // SET_CPU_SPEED
    SETTING(opt_yes_no),      // SET_CGA_GFX (Yes = the card's I/O decode responds)
    SETTING(opt_yes_no),      // SET_HGC_GFX
    SETTING(opt_video_1st),   // SET_VIDEO_1ST (applied by the BIOS at the next Reset PC)
    SETTING(opt_bios_wr),     // SET_BIOS_WR
    SETTING_D(opt_off_on, 1), // SET_SPLASH (default On; read at cold boot)
    SETTING(opt_opl2),        // SET_OPL2
    SETTING(opt_boost),       // SET_BOOST
    SETTING(opt_level4),      // SET_SPK_VOL
    SETTING(opt_stereo),      // SET_STEREO
    SETTING_D(opt_dis_en, 1), // SET_CMS (default Enabled)
    SETTING(opt_off_on),      // SET_COMPOSITE
    SETTING(opt_display),     // SET_DISPLAY
    SETTING_D(opt_dis_en, 1), // SET_EMS (default Enabled, as the fixed memory map was)
    SETTING(opt_ems_frame),   // SET_EMS_FRAME
    SETTING_D(opt_dis_en, 1), // SET_A000 (default Enabled)
    SETTING_D(opt_joy, 1),    // SET_JOY1 (default Digital; built-in pad has no stick)
    SETTING_D(opt_joy, 2),    // SET_JOY2 (default Disabled)
    SETTING(opt_no_yes),      // SET_SWAPJOY
    SETTING(opt_no_yes),      // SET_SYNCJOY
    SETTING(opt_dpad),        // SET_DPAD (default Numpad)
    SETTING(opt_gamepad),     // SET_GAMEPAD (default Keyboard)
};

// Compiled defaults, snapshotted at boot before the save is adopted, for Reset to Defaults.
static uint8_t settings_default[SET_COUNT];

// A menu row is a submenu link, an editable option, a controller-button binding, an action, or a
// blank grouping spacer; `arg` selects the target menu, the setting id, the BIND_* button, or the
// action respectively (unused for a spacer).
enum { IT_SUBMENU, IT_OPTION, IT_KEYBIND, IT_ACTION, IT_SPACER };

typedef struct {
    const char *label;
    uint8_t type;
    uint8_t arg;
} item_t;

enum { MENU_MAIN, MENU_SYSTEM, MENU_AV, MENU_HW, MENU_CONTROLS, MENU_COUNT };
enum { ACT_CREDITS, ACT_DEFAULTS, ACT_RESET_PC, ACT_SWITCH_VIDEO };

static const item_t items_main[] = {
    { "System", IT_SUBMENU, MENU_SYSTEM },
    { "Audio & Video", IT_SUBMENU, MENU_AV },
    { "Hardware", IT_SUBMENU, MENU_HW },
    { "Controls", IT_SUBMENU, MENU_CONTROLS },
    { "", IT_SPACER, 0 },
    { "Show Credits", IT_ACTION, ACT_CREDITS },
#if ENABLE_HGC
    { "Switch Video", IT_ACTION, ACT_SWITCH_VIDEO },
#endif
    { "Reset to Defaults", IT_ACTION, ACT_DEFAULTS },
    { "", IT_SPACER, 0 },
    { "Reset PC", IT_ACTION, ACT_RESET_PC },
};

static const item_t items_system[] = {
    { "CPU Speed", IT_OPTION, SET_CPU_SPEED },
#if ENABLE_HGC
    { "CGA Graphics", IT_OPTION, SET_CGA_GFX },
    { "Hercules Graphics", IT_OPTION, SET_HGC_GFX },
    { "1st Video", IT_OPTION, SET_VIDEO_1ST },
#endif
    { "BIOS Writable", IT_OPTION, SET_BIOS_WR },
    { "Boot Splash", IT_OPTION, SET_SPLASH },
};

static const item_t items_av[] = {
    { "OPL2 Audio", IT_OPTION, SET_OPL2 },
    { "Audio Boost", IT_OPTION, SET_BOOST },
    { "Speaker Volume", IT_OPTION, SET_SPK_VOL },
    { "Stereo Mix", IT_OPTION, SET_STEREO },
    { "C/MS Audio", IT_OPTION, SET_CMS },
    { "Composite", IT_OPTION, SET_COMPOSITE },
    { "Display", IT_OPTION, SET_DISPLAY },
};

static const item_t items_hw[] = {
    { "Lo-tech 2MB EMS", IT_OPTION, SET_EMS },
    { "EMS Frame", IT_OPTION, SET_EMS_FRAME },
    { "A000 UMB", IT_OPTION, SET_A000 },
    { "Joystick 1", IT_OPTION, SET_JOY1 },
    { "Joystick 2", IT_OPTION, SET_JOY2 },
    { "Swap Joysticks", IT_OPTION, SET_SWAPJOY },
    { "Sync Joy to CPU", IT_OPTION, SET_SYNCJOY },
};

// Gamepad Mode picks what controller 1 drives: the D-pad preset and button binds below take effect
// only in its Keyboard mode. L1 is absent because it stays the fixed VKB toggle. Each button row
// cycles its binding through Unmapped, the OSD functions, and a key (picked on the virtual
// keyboard); see the IT_KEYBIND handling in settings_input.
static const item_t items_controls[] = {
    { "Gamepad Mode", IT_OPTION, SET_GAMEPAD },
    { "D-pad", IT_OPTION, SET_DPAD },
    { "Button A", IT_KEYBIND, BIND_A },
    { "Button B", IT_KEYBIND, BIND_B },
    { "Button X", IT_KEYBIND, BIND_X },
    { "Button Y", IT_KEYBIND, BIND_Y },
    { "Button R1", IT_KEYBIND, BIND_R1 },
    { "Button Select", IT_KEYBIND, BIND_SELECT },
    { "Button Start", IT_KEYBIND, BIND_START },
};

typedef struct {
    const char *title;
    const item_t *items;
    uint8_t count;
} menu_t;

#define MENU(title, arr) { (title), (arr), (uint8_t) (sizeof(arr) / sizeof((arr)[0])) }

static const menu_t menus[MENU_COUNT] = {
    MENU("Settings", items_main),
    MENU("System", items_system),
    MENU("Audio & Video", items_av),
    MENU("Hardware", items_hw),
    MENU("Controls", items_controls),
};

static uint8_t cur_menu;       // MENU_* currently shown
static uint8_t cur_row;        // cursor index within that menu
static uint8_t return_row;     // main-menu row to restore when a submenu is left
static volatile uint8_t dirty; // a value changed since the last persist

static void draw_frame(void)
{
    osd_draw_char(&panel, 0, 0, G_TL, OSD_KEYEDGE);
    osd_draw_char(&panel, (PANEL_COLS - 1) * 8, 0, G_TR, OSD_KEYEDGE);
    osd_draw_char(&panel, 0, (PANEL_ROWS - 1) * 8, G_BL, OSD_KEYEDGE);
    osd_draw_char(&panel, (PANEL_COLS - 1) * 8, (PANEL_ROWS - 1) * 8, G_BR, OSD_KEYEDGE);
    for (int c = 1; c < PANEL_COLS - 1; c++) {
        osd_draw_char(&panel, c * 8, 0, G_HORIZ, OSD_KEYEDGE);
        osd_draw_char(&panel, c * 8, (PANEL_ROWS - 1) * 8, G_HORIZ, OSD_KEYEDGE);
    }
    for (int r = 1; r < PANEL_ROWS - 1; r++) {
        osd_draw_char(&panel, 0, r * 8, G_VERT, OSD_KEYEDGE);
        osd_draw_char(&panel, (PANEL_COLS - 1) * 8, r * 8, G_VERT, OSD_KEYEDGE);
    }
}

// Names for the common keys a docked keyboard can bind that the 83-key virtual keyboard omits: the
// E0-extended keys (ext = 1) and the 101-key extras beyond the XT layout (F11/F12, Print Screen,
// Pause). Set-2 codes and ext flag per hid_to_ps2; anything rarer falls back to its raw code.
static const struct {
    uint8_t ext;
    uint8_t code;
    const char *name;
} extra_names[] = { { 1, 0x75, "Up" }, { 1, 0x72, "Down" }, { 1, 0x6B, "Left" },
    { 1, 0x74, "Right" }, { 1, 0x6C, "Home" }, { 1, 0x69, "End" }, { 1, 0x7D, "PgUp" },
    { 1, 0x7A, "PgDn" }, { 1, 0x70, "Insert" }, { 1, 0x71, "Delete" }, { 1, 0x4A, "KP /" },
    { 1, 0x5A, "KP Enter" }, { 1, 0x14, "R Ctrl" }, { 1, 0x11, "R Alt" }, { 0, 0x78, "F11" },
    { 0, 0x07, "F12" }, { 0, 0xE2, "PrtSc" }, { 0, 0xE1, "Pause" } };

// An unnamed key's raw Set-2 scancode in hex ("E0 " prefixing an extended one), so it stays
// identifiable rather than blank.
static const char *hex_scancode(int ext, uint8_t code)
{
    static const char digits[] = "0123456789ABCDEF";
    static char buf[6];
    char *p = buf;
    if (ext) {
        *p++ = 'E';
        *p++ = '0';
        *p++ = ' ';
    }
    *p++ = digits[code >> 4];
    *p++ = digits[code & 0xF];
    *p = '\0';
    return buf;
}

// The current binding for a button's row value: a function or Unmapped label, a plain key's
// virtual-keyboard legend (blank-legend space bar named), a named extra key, else the raw scancode.
static const char *bind_name(int btn)
{
    switch (key_bind_function(btn)) {
    case BTNFN_SETTINGS:
        return "Open Settings";
    case BTNFN_CREDITS:
        return "Show Credits";
    case BTNFN_VIDEO:
        return "Switch Video";
    default:
        break;
    }
    uint8_t code = key_bind_code(btn);
    if (code == 0) {
        return "Unmapped";
    }
    int ext = key_bind_ext(btn);
    if (!ext) {
        for (int i = 0; i < vkb_key_count; i++) {
            if (vkb_keys[i].scancode == code) {
                return vkb_keys[i].label[0] ? vkb_keys[i].label : "Space";
            }
        }
    }
    for (uint32_t i = 0; i < sizeof(extra_names) / sizeof(extra_names[0]); i++) {
        if (extra_names[i].ext == ext && extra_names[i].code == code) {
            return extra_names[i].name;
        }
    }
    return hex_scancode(ext, code);
}

// A button binding row cycles through Unmapped, the OSD functions, and a final "pick a key" slot;
// landing on that slot opens the key picker rather than storing a code. The functions carry their
// BTNFN_* sentinel (BTNFN_* + 0xF0); BIND_KEY_SLOT is not a storable code.
#define BIND_KEY_SLOT 0xFFu
static const uint8_t keybind_cycle[] = {
    0x00,                   // Unmapped
    0xF0u + BTNFN_SETTINGS, // Open Settings
    0xF0u + BTNFN_CREDITS,  // Show Credits
#if ENABLE_HGC
    0xF0u + BTNFN_VIDEO, // Switch Video
#endif
    BIND_KEY_SLOT, // pick a key
};
#define KEYBIND_CYCLE_COUNT ((int) (sizeof(keybind_cycle) / sizeof(keybind_cycle[0])))

// Which cycle slot a button's current binding sits on; a keyboard key (matching no code above)
// rests on the final key slot.
static int keybind_slot(int btn)
{
    uint8_t code = key_bind_code(btn);
    for (int i = 0; i < KEYBIND_CYCLE_COUNT; i++) {
        if (keybind_cycle[i] == code) {
            return i;
        }
    }
    return KEYBIND_CYCLE_COUNT - 1;
}

// Per-row cursor slot (keybind_sel) and last-held key (keybind_key + keybind_key_ext bitmap), kept
// because neither survives the roller leaving the key slot: rolling off and back restores the key.
static uint8_t keybind_sel[BIND_COUNT];
static uint8_t keybind_key[BIND_COUNT];
static uint8_t keybind_key_ext; // E0 flag of each remembered key, one bit per button

// True when a button holds a real keyboard key (not Unmapped, not a function).
static int keybind_is_key(int btn)
{
    return key_bind_code(btn) != 0 && key_bind_function(btn) == BTNFN_NONE;
}

// Snapshot a button's current key (code + ext) into the row's memory; a non-key clears it.
static void keybind_remember(int btn)
{
    int is_key = keybind_is_key(btn);
    keybind_key[btn] = is_key ? key_bind_code(btn) : 0;
    if (is_key && key_bind_ext(btn)) {
        keybind_key_ext |= (uint8_t) (1u << btn);
    } else {
        keybind_key_ext &= (uint8_t) ~(1u << btn);
    }
}

// Seed each button row's cursor slot and remembered key from its binding; called when the Controls
// menu opens.
static void keybind_sync(void)
{
    for (int b = 0; b < BIND_COUNT; b++) {
        keybind_sel[b] = (uint8_t) keybind_slot(b);
        keybind_remember(b);
    }
}

// Repaint one menu row: erase its interior (the frame columns stay), then the cursor, label, and
// either the current value (option/binding) or a submenu marker.
static void draw_row(int i)
{
    const item_t *it = &menus[cur_menu].items[i];
    int y = (ROW_FIRST + i) * 8;

    osd_fill_rect(&panel, 8, y, (PANEL_COLS - 2) * 8, 8, OSD_KEYFACE);
    if (it->type == IT_SPACER) {
        return; // a blank row that visually groups the items around it
    }
    if (i == cur_row) {
        osd_draw_char(&panel, COL_CURSOR * 8, y, G_MARKER, OSD_CURSOR);
    }
    osd_draw_string(&panel, COL_LABEL * 8, y, it->label, OSD_LABEL);
    if (it->type == IT_OPTION) {
        const setting_t *s = &settings[it->arg];
        osd_draw_string(&panel, COL_VALUE * 8, y, s->opts[s->value], OSD_LABEL);
    } else if (it->type == IT_KEYBIND) {
        int on_key = keybind_cycle[keybind_sel[it->arg]] == BIND_KEY_SLOT;
        const char *val = (on_key && !keybind_is_key(it->arg)) ? "[Set key]" : bind_name(it->arg);
        osd_draw_string(&panel, COL_VALUE * 8, y, val, OSD_LABEL);
    } else if (it->type == IT_SUBMENU) {
        osd_draw_char(&panel, COL_VALUE * 8, y, G_MARKER, OSD_LABEL);
    }
}

static void settings_draw(void)
{
    osd_fill_rect(&panel, 0, 0, PANEL_W, PANEL_H, OSD_KEYFACE);
    draw_frame();
    osd_draw_string(&panel, COL_TITLE * 8, ROW_TITLE * 8, menus[cur_menu].title, OSD_LABEL);
    for (int i = 0; i < menus[cur_menu].count; i++) {
        draw_row(i);
    }
    // Control hint along the bottom row (CP437 arrows for Left/Right), dimmed as secondary text.
    static const char hint[] = "\x1b\x1a Change   A/B Enter/Back";
    int hx = (PANEL_COLS - 1 - (int) (sizeof(hint) - 1)) * 8;
    osd_draw_string(&panel, hx, (PANEL_ROWS - 2) * 8, hint, OSD_DISABLED);
}

// Move the cursor within the current menu (wrapping), repainting only the two affected rows.
static void move_cursor(int dir)
{
    int n = menus[cur_menu].count;
    int old = cur_row;
    int nr = cur_row;
    // Step over blank spacer rows so the cursor only ever lands on a real item.
    do {
        nr += dir;
        if (nr < 0) {
            nr = n - 1;
        }
        if (nr >= n) {
            nr = 0;
        }
    } while (menus[cur_menu].items[nr].type == IT_SPACER);
    cur_row = (uint8_t) nr;
    draw_row(old);
    draw_row(cur_row);
}

void settings_open(void)
{
    cur_menu = MENU_MAIN;
    cur_row = 0;
    return_row = 0;
    osd_clear_screen(); // erase any previous overlay
    settings_draw();
}

void settings_reopen(void)
{
    osd_clear_screen(); // erase the key picker
    settings_draw();
}

void settings_show_credits(void)
{
    *OSD_ACTION = 0;               // re-arm the edge (may still be set from a prior request)
    *OSD_ACTION = OSD_ACT_CREDITS; // rising edge -> credits overlay
}

// Drive one setting into the machine: SET_DPAD expands to the D-pad key_cfg slots, every other
// setting drives its osd_settings register.
static void settings_push(uint32_t i)
{
    if (i == SET_DPAD) {
        dpad_apply(settings[i].value);
    } else {
        *SETTINGS_REG = (i << 8) | settings[i].value;
    }
}

// Restore every setting and button binding to its compiled default, apply it live, and flag the
// save dirty.
static void settings_reset_defaults(void)
{
    for (uint32_t i = 0; i < SET_COUNT; i++) {
        settings[i].value = settings_default[i];
        settings_push(i);
    }
    key_bind_reset();
    dirty = 1;
    settings_draw();
}

int settings_input(uint16_t pressed)
{
    if (pressed & BTN_B) {
        if (cur_menu == MENU_MAIN) {
            return 1; // dismiss the overlay
        }
        cur_menu = MENU_MAIN;
        cur_row = return_row;
        settings_draw();
        return 0;
    }
    if (pressed & (BTN_UP | BTN_DOWN)) {
        move_cursor((pressed & BTN_UP) ? -1 : 1);
        return 0;
    }

    // Left/Right change a row's value; A enters (a submenu, an action, or the key picker); B leaves
    // (handled above). The two roles never overlap, so a stray double-press cannot both navigate
    // and edit.
    const item_t *it = &menus[cur_menu].items[cur_row];
    if (it->type == IT_OPTION) {
        setting_t *s = &settings[it->arg];
        int changed = 1;
        if (pressed & BTN_RIGHT) {
            s->value = (uint8_t) ((s->value + 1) % s->count);
        } else if (pressed & BTN_LEFT) {
            s->value = (uint8_t) ((s->value + s->count - 1) % s->count);
        } else {
            changed = 0;
        }
        if (changed) {
            // Drive the change into the machine and flag dirty so the main loop refreshes the save.
            settings_push(it->arg);
            dirty = 1;
            draw_row(cur_row);
        }
    } else if (it->type == IT_SUBMENU) {
        if (pressed & BTN_A) {
            return_row = cur_row;
            cur_menu = it->arg;
            cur_row = 0;
            if (cur_menu == MENU_CONTROLS) {
                keybind_sync();
            }
            settings_draw();
        }
    } else if (it->type == IT_KEYBIND) {
        int btn = it->arg;
        int slot = keybind_sel[btn];
        if ((pressed & BTN_A) && keybind_cycle[slot] == BIND_KEY_SLOT) {
            // Parked on the key slot: open the virtual keyboard as a key picker. It stores the key
            // and returns to this row, or leaves the binding unchanged if cancelled.
            vkb_ui_open_picker(btn);
        } else {
            int dir = (pressed & BTN_RIGHT) ? 1 : (pressed & BTN_LEFT) ? -1 : 0;
            if (dir) {
                // Remember the key being left so rolling back to the key slot restores it.
                if (keybind_cycle[slot] == BIND_KEY_SLOT) {
                    keybind_remember(btn);
                }
                slot = (slot + dir + KEYBIND_CYCLE_COUNT) % KEYBIND_CYCLE_COUNT;
                keybind_sel[btn] = (uint8_t) slot;
                uint8_t code = keybind_cycle[slot];
                if (code == BIND_KEY_SLOT) {
                    key_bind_set(btn, keybind_key[btn], (keybind_key_ext >> btn) & 1);
                } else {
                    key_bind_set(btn, code, 0);
                }
                settings_mark_dirty();
                draw_row(cur_row);
            }
        }
    } else if (it->type == IT_ACTION) {
        if (pressed & BTN_A) {
            if (it->arg == ACT_RESET_PC) {
                // Orchestrated guest reset: assert the boot-master hold (the guest re-latches
                // the live settings when it releases), hold briefly, then release. The softcore
                // keeps running, so disks stay mounted and the guest re-detects them.
                *SOFT_GUEST_HOLD = 1;
                for (volatile int i = 0; i < 1000; i++)
                    ;
                *SOFT_GUEST_HOLD = 0;
                return 1; // close the panel so the re-POST shows on a clean screen
            } else if (it->arg == ACT_DEFAULTS) {
                settings_reset_defaults();
            } else if (it->arg == ACT_CREDITS) {
                settings_show_credits();
                return 1; // close the panel so the credits scroll shows on a clean screen
#if ENABLE_HGC
            } else if (it->arg == ACT_SWITCH_VIDEO) {
                *OSD_ACTION = 0;             // re-arm the edge
                *OSD_ACTION = OSD_ACT_VIDEO; // rising edge -> toggle the displayed video card
#endif
            }
        }
    }
    return 0;
}

// Persisted settings live in the nonvolatile dataslot's window in the disk bridge RAM (word
// SETTINGS_WORD, the slot's 0x60000200 address; the low 512 bytes are the disk sector buffer). APF
// loads that window from /Saves at boot and flushes it back when the core is shut down, so the
// softcore only keeps it current. Layout: word0 magic, word1 {version[7:0], count[15:8]}, the
// values packed four per word, then the key-binding block (seven codes + ext byte) four per word. A
// blob older than version 4 predates the menu-group value layout, so it is rejected and the
// compiled defaults load.
#define SETTINGS_MAGIC   0x50435853u
#define SETTINGS_VERSION 4u
#define SETTINGS_WORD    128

void settings_load(void)
{
    for (uint32_t i = 0; i < SET_COUNT; i++) {
        settings_default[i] = settings[i].value; // capture defaults before the save overwrites them
    }
    *FDD_BRAM_ADDR = SETTINGS_WORD;
    uint32_t magic = *FDD_BRAM_RDATA;
    uint32_t head = *FDD_BRAM_RDATA;
    uint32_t version = head & 0xFF;
    if (magic == SETTINGS_MAGIC && version >= 4 && version <= SETTINGS_VERSION) {
        uint32_t count = (head >> 8) & 0xFF;
        if (count > SET_COUNT) {
            count = SET_COUNT;
        }
        uint32_t word = 0;
        for (uint32_t i = 0; i < count; i++) {
            if ((i & 3) == 0) {
                word = *FDD_BRAM_RDATA;
            }
            uint8_t v = (word >> ((i & 3) * 8)) & 0xFF;
            // Ignore an out-of-range value from an older blob.
            if (v < settings[i].count) {
                settings[i].value = v;
            }
        }
        // The binding block follows the values (auto-incrementing read pointer): seven code bytes
        // then the ext bitmap.
        uint8_t codes[BIND_COUNT];
        uint8_t ext = 0;
        for (uint32_t i = 0; i < BIND_COUNT + 1; i++) {
            if ((i & 3) == 0) {
                word = *FDD_BRAM_RDATA;
            }
            uint8_t b = (word >> ((i & 3) * 8)) & 0xFF;
            if (i < BIND_COUNT) {
                codes[i] = b;
            } else {
                ext = b;
            }
        }
        for (uint32_t i = 0; i < BIND_COUNT; i++) {
            key_bind_set(i, codes[i], (ext >> i) & 1);
        }
    }
    // Drive every setting into the machine so it follows the compiled defaults on a fresh boot and
    // the saved values once a blob exists.
    for (uint32_t i = 0; i < SET_COUNT; i++) {
        settings_push(i);
    }
}

void settings_mark_dirty(void)
{
    dirty = 1;
}

void settings_service(void)
{
    if (!dirty) {
        return;
    }
    dirty = 0;
    *FDD_BRAM_ADDR = SETTINGS_WORD;
    *FDD_BRAM_WDATA = SETTINGS_MAGIC;
    *FDD_BRAM_WDATA = SETTINGS_VERSION | ((uint32_t) SET_COUNT << 8);
    uint32_t word = 0;
    for (uint32_t i = 0; i < SET_COUNT; i++) {
        word |= (uint32_t) settings[i].value << ((i & 3) * 8);
        if ((i & 3) == 3 || i == SET_COUNT - 1) {
            *FDD_BRAM_WDATA = word;
            word = 0;
        }
    }
    // key-binding block: seven code bytes then the ext bitmap, four bytes per word.
    uint8_t ext = 0;
    for (uint32_t i = 0; i < BIND_COUNT; i++) {
        ext |= (uint8_t) (key_bind_ext(i) << i);
    }
    word = 0;
    for (uint32_t i = 0; i < BIND_COUNT + 1; i++) {
        uint8_t b = (i < BIND_COUNT) ? key_bind_code(i) : ext;
        word |= (uint32_t) b << ((i & 3) * 8);
        if ((i & 3) == 3 || i == BIND_COUNT) {
            *FDD_BRAM_WDATA = word;
            word = 0;
        }
    }
}
