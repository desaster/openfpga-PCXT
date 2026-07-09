#include "settings_ui.h"

#include "softcpu_regs.h"
#include "vkb_draw.h"

// The settings overlay: a CP437-framed panel of submenus, drawn on demand into the shared OSD
// framebuffer and navigated with the D-pad. Each edit updates the value in RAM and pushes it to the
// softcore settings register that drives the machine.

// Panel geometry in 8px character cells, centred in the framebuffer.
#define PANEL_COLS 44
#define PANEL_ROWS 14
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
    SET_CPU_SPEED,
    SET_BIOS_WR,
    SET_OPL2,
    SET_BOOST,
    SET_SPK_VOL,
    SET_STEREO,
    SET_CMS,
    SET_COMPOSITE,
    SET_DISPLAY,
    SET_EMS,
    SET_EMS_FRAME,
    SET_A000,
    SET_JOY1,
    SET_JOY2,
    SET_SWAPJOY,
    SET_SYNCJOY,
    SET_COUNT
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

typedef struct {
    const char *const *opts;
    uint8_t count;
    uint8_t value;
    uint8_t locked; // shown but not editable (no hardware path for the setting)
} setting_t;

#define SETTING(a)           { (a), (uint8_t) (sizeof(a) / sizeof((a)[0])), 0, 0 }
#define SETTING_D(a, d)      { (a), (uint8_t) (sizeof(a) / sizeof((a)[0])), (d), 0 }
#define SETTING_LOCKED(a, v) { (a), (uint8_t) (sizeof(a) / sizeof((a)[0])), (v), 1 }

static setting_t settings[SET_COUNT] = {
    SETTING(opt_cpu),              // SET_CPU_SPEED
    SETTING(opt_bios_wr),          // SET_BIOS_WR
    SETTING(opt_opl2),             // SET_OPL2
    SETTING(opt_boost),            // SET_BOOST
    SETTING(opt_level4),           // SET_SPK_VOL
    SETTING_LOCKED(opt_stereo, 0), // SET_STEREO
    SETTING_LOCKED(opt_dis_en, 0), // SET_CMS
    SETTING(opt_off_on),           // SET_COMPOSITE
    SETTING(opt_display),          // SET_DISPLAY
    SETTING_D(opt_dis_en, 1),      // SET_EMS (default Enabled, as the fixed memory map was)
    SETTING(opt_ems_frame),        // SET_EMS_FRAME
    SETTING_D(opt_dis_en, 1),      // SET_A000 (default Enabled)
    SETTING_D(opt_joy, 1),         // SET_JOY1 (default Digital; built-in pad has no stick)
    SETTING_D(opt_joy, 2),         // SET_JOY2 (default Disabled)
    SETTING(opt_no_yes),           // SET_SWAPJOY
    SETTING(opt_no_yes),           // SET_SYNCJOY
};

// Compiled defaults, snapshotted at boot before the save is adopted, for Reset to Defaults.
static uint8_t settings_default[SET_COUNT];

// A menu row is a submenu link, an editable option, or an action; `arg` selects the target menu,
// the setting id, or the action respectively.
enum { IT_SUBMENU, IT_OPTION, IT_ACTION };

typedef struct {
    const char *label;
    uint8_t type;
    uint8_t arg;
} item_t;

enum { MENU_MAIN, MENU_SYSTEM, MENU_AV, MENU_HW, MENU_COUNT };
enum { ACT_CREDITS, ACT_DEFAULTS, ACT_RESET_PC };

static const item_t items_main[] = {
    { "System", IT_SUBMENU, MENU_SYSTEM },
    { "Audio & Video", IT_SUBMENU, MENU_AV },
    { "Hardware", IT_SUBMENU, MENU_HW },
    { "Show Credits", IT_ACTION, ACT_CREDITS },
    { "Reset to Defaults", IT_ACTION, ACT_DEFAULTS },
    { "Reset PC", IT_ACTION, ACT_RESET_PC },
};

static const item_t items_system[] = {
    { "CPU Speed", IT_OPTION, SET_CPU_SPEED },
    { "BIOS Writable", IT_OPTION, SET_BIOS_WR },
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

// Repaint one menu row: erase its interior (the frame columns stay), then the cursor, label, and
// either the current value (option) or a submenu marker. A locked option is drawn dimmed so it
// reads as unavailable.
static void draw_row(int i)
{
    const item_t *it = &menus[cur_menu].items[i];
    int y = (ROW_FIRST + i) * 8;
    int locked = (it->type == IT_OPTION) && settings[it->arg].locked;
    uint8_t text = locked ? OSD_DISABLED : OSD_LABEL;

    osd_fill_rect(&panel, 8, y, (PANEL_COLS - 2) * 8, 8, OSD_KEYFACE);
    if (i == cur_row) {
        osd_draw_char(&panel, COL_CURSOR * 8, y, G_MARKER, OSD_CURSOR);
    }
    osd_draw_string(&panel, COL_LABEL * 8, y, it->label, text);
    if (it->type == IT_OPTION) {
        const setting_t *s = &settings[it->arg];
        osd_draw_string(&panel, COL_VALUE * 8, y, s->opts[s->value], text);
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
}

// Move the cursor within the current menu (wrapping), repainting only the two affected rows.
static void move_cursor(int dir)
{
    int n = menus[cur_menu].count;
    int old = cur_row;
    int nr = (int) cur_row + dir;
    if (nr < 0) {
        nr = n - 1;
    }
    if (nr >= n) {
        nr = 0;
    }
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

void settings_show_credits(void)
{
    *OSD_ACTION = 0;               // re-arm the edge (may still be set from a prior request)
    *OSD_ACTION = OSD_ACT_CREDITS; // rising edge -> credits overlay
}

// Restore every setting to its compiled default, apply it live, and flag the save dirty.
static void settings_reset_defaults(void)
{
    for (uint32_t i = 0; i < SET_COUNT; i++) {
        settings[i].value = settings_default[i];
        *SETTINGS_REG = (i << 8) | settings[i].value;
    }
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

    const item_t *it = &menus[cur_menu].items[cur_row];
    if (it->type == IT_OPTION) {
        setting_t *s = &settings[it->arg];
        if (s->locked) {
            return 0; // locked: shown but not editable
        }
        int changed = 1;
        if (pressed & (BTN_A | BTN_RIGHT)) {
            s->value = (uint8_t) ((s->value + 1) % s->count);
        } else if (pressed & BTN_LEFT) {
            s->value = (uint8_t) ((s->value + s->count - 1) % s->count);
        } else {
            changed = 0;
        }
        if (changed) {
            // Push {id, value} to the softcore settings register; the machine follows for the
            // settings wired there. Flag dirty so the main loop refreshes the save window.
            *SETTINGS_REG = ((uint32_t) it->arg << 8) | s->value;
            dirty = 1;
            draw_row(cur_row);
        }
    } else if (it->type == IT_SUBMENU) {
        if (pressed & (BTN_A | BTN_RIGHT)) {
            return_row = cur_row;
            cur_menu = it->arg;
            cur_row = 0;
            settings_draw();
        }
    } else if (it->type == IT_ACTION) {
        if (pressed & (BTN_A | BTN_RIGHT)) {
            if (it->arg == ACT_RESET_PC) {
                *OSD_ACTION = OSD_ACT_RESET; // reboots the softcore with the guest
            } else if (it->arg == ACT_DEFAULTS) {
                settings_reset_defaults();
            } else if (it->arg == ACT_CREDITS) {
                settings_show_credits();
                return 1; // close the panel so the credits scroll shows on a clean screen
            }
        }
    }
    return 0;
}

// Persisted settings live in the nonvolatile dataslot's window in the disk bridge RAM (word
// SETTINGS_WORD, the slot's 0x60000200 address; the low 512 bytes are the disk sector buffer). APF
// loads that window from /Saves at boot and flushes it back when the core is shut down, so the
// softcore only keeps it current. Layout: word0 magic, word1 {version[7:0], count[15:8]}, then the
// values packed four per word.
#define SETTINGS_MAGIC   0x50435853u
#define SETTINGS_VERSION 2u
#define SETTINGS_WORD    128

void settings_load(void)
{
    for (uint32_t i = 0; i < SET_COUNT; i++) {
        settings_default[i] = settings[i].value; // capture defaults before the save overwrites them
    }
    *FDD_BRAM_ADDR = SETTINGS_WORD;
    uint32_t magic = *FDD_BRAM_RDATA;
    uint32_t head = *FDD_BRAM_RDATA;
    if (magic == SETTINGS_MAGIC && (head & 0xFF) == SETTINGS_VERSION) {
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
            // Ignore an out-of-range value from an older blob, and never let a saved value pull a
            // locked setting off its pinned default.
            if (v < settings[i].count && !settings[i].locked) {
                settings[i].value = v;
            }
        }
    }
    // Drive every setting into the softcore register file so the machine follows the compiled
    // defaults on a fresh boot and the saved values once a blob exists.
    for (uint32_t i = 0; i < SET_COUNT; i++) {
        *SETTINGS_REG = (i << 8) | settings[i].value;
    }
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
}
