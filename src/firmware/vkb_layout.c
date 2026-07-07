#include "vkb_layout.h"

#define K(x, y, w, h, sc, lbl)     { (x), (y), (w), (h), (sc), (lbl), 0, OSD_KEYFACE }
#define K2(x, y, w, h, sc, l1, l2) { (x), (y), (w), (h), (sc), (l1), (l2), OSD_KEYFACE }
// Accent-face variants, for the function and control keys.
#define KA(x, y, w, h, sc, lbl)     { (x), (y), (w), (h), (sc), (lbl), 0, OSD_KEYACCENT }
#define K2A(x, y, w, h, sc, l1, l2) { (x), (y), (w), (h), (sc), (l1), (l2), OSD_KEYACCENT }

// CP437 arrow glyphs, for the keypad arrow legends.
#define GL_LEFT  "\x1b" // <-
#define GL_RIGHT "\x1a" // ->
#define GL_UP    "\x18" // ^
#define GL_DOWN  "\x19" // v

// Our own glyphs, drawn into unused CP437 slots in the PNG.
#define G_END   "\x01"
#define G_HOME  "\x02"
#define G_PGUP  "\x03"
#define G_PGDN  "\x04"
#define G_SHIFT "\x05"
#define G_RET   "\x06"
#define G_PRTSC "\x07"

// PC/XT 83-key layout: per-key pixel rectangles within the framebuffer, with
// Set-2 make codes; keys are 1px-rounded. A dual legend (K2) prints its two
// values top-left / bottom-right; the KA/K2A variants give function and control
// keys the accent face.
const vkb_key_t vkb_keys[] = {
    // row 0
    KA(2, 1, 28, 15, 0x05, "F1 "),
    KA(32, 1, 28, 15, 0x06, "F2 "),
    KA(74, 1, 28, 15, 0x76, "Esc"),
    K2(104, 1, 28, 15, 0x16, "1", "!"),
    K2(134, 1, 28, 15, 0x1E, "2", "@"),
    K2(164, 1, 28, 15, 0x26, "3", "#"),
    K2(194, 1, 28, 15, 0x25, "4", "$"),
    K2(224, 1, 28, 15, 0x2E, "5", "%"),
    K2(254, 1, 28, 15, 0x36, "6", "^"),
    K2(284, 1, 28, 15, 0x3D, "7", "&"),
    K2(314, 1, 28, 15, 0x3E, "8", "*"),
    K2(344, 1, 28, 15, 0x46, "9", "("),
    K2(374, 1, 28, 15, 0x45, "0", ")"),
    K2(404, 1, 28, 15, 0x4E, "-", "_"),
    K2(434, 1, 28, 15, 0x55, "=", "+"),
    KA(464, 1, 50, 15, 0x66, GL_LEFT),
    KA(516, 1, 58, 15, 0x77, "NumL"),
    KA(576, 1, 58, 15, 0x7E, "ScrL"),
    // row 1
    KA(2, 17, 28, 15, 0x04, "F3 "),
    KA(32, 17, 28, 15, 0x0C, "F4 "),
    KA(74, 17, 43, 15, 0x0D, "Tab"),
    K(119, 17, 28, 15, 0x15, "Q"),
    K(149, 17, 28, 15, 0x1D, "W"),
    K(179, 17, 28, 15, 0x24, "E"),
    K(209, 17, 28, 15, 0x2D, "R"),
    K(239, 17, 28, 15, 0x2C, "T"),
    K(269, 17, 28, 15, 0x35, "Y"),
    K(299, 17, 28, 15, 0x3C, "U"),
    K(329, 17, 28, 15, 0x43, "I"),
    K(359, 17, 28, 15, 0x44, "O"),
    K(389, 17, 28, 15, 0x4D, "P"),
    K2(419, 17, 28, 15, 0x54, "[", "{"),
    K2(449, 17, 35, 15, 0x5B, "]", "}"),
    KA(486, 17, 28, 31, 0x5A, G_RET),
    K2(516, 17, 28, 15, 0x6C, "7", G_HOME),
    K2(546, 17, 28, 15, 0x75, "8", GL_UP),
    K2(576, 17, 28, 15, 0x7D, "9", G_PGUP),
    KA(606, 17, 28, 15, 0x7B, "-"),
    // row 2
    KA(2, 33, 28, 15, 0x03, "F5 "),
    KA(32, 33, 28, 15, 0x0B, "F6 "),
    KA(74, 33, 50, 15, 0x14, "Ctrl"),
    K(126, 33, 28, 15, 0x1C, "A"),
    K(156, 33, 28, 15, 0x1B, "S"),
    K(186, 33, 28, 15, 0x23, "D"),
    K(216, 33, 28, 15, 0x2B, "F"),
    K(246, 33, 28, 15, 0x34, "G"),
    K(276, 33, 28, 15, 0x33, "H"),
    K(306, 33, 28, 15, 0x3B, "J"),
    K(336, 33, 28, 15, 0x42, "K"),
    K(366, 33, 28, 15, 0x4B, "L"),
    K2(396, 33, 28, 15, 0x4C, ";", ":"),
    K2(426, 33, 28, 15, 0x52, "'", "\""),
    K2(456, 33, 28, 15, 0x0E, "`", "~"),
    K2(516, 33, 28, 15, 0x6B, "4", GL_LEFT),
    K(546, 33, 28, 15, 0x73, "5"),
    K2(576, 33, 28, 15, 0x74, "6", GL_RIGHT),
    KA(606, 33, 28, 47, 0x79, "+"),
    // row 3
    KA(2, 49, 28, 15, 0x83, "F7 "),
    KA(32, 49, 28, 15, 0x0A, "F8 "),
    KA(74, 49, 35, 15, 0x12, G_SHIFT),
    K(111, 49, 28, 15, 0x5D, "\\"),
    K(141, 49, 28, 15, 0x1A, "Z"),
    K(171, 49, 28, 15, 0x22, "X"),
    K(201, 49, 28, 15, 0x21, "C"),
    K(231, 49, 28, 15, 0x2A, "V"),
    K(261, 49, 28, 15, 0x32, "B"),
    K(291, 49, 28, 15, 0x31, "N"),
    K(321, 49, 28, 15, 0x3A, "M"),
    K2(351, 49, 28, 15, 0x41, ",", "<"),
    K2(381, 49, 28, 15, 0x49, ".", ">"),
    K2(411, 49, 28, 15, 0x4A, "/", "?"),
    KA(441, 49, 43, 15, 0x59, G_SHIFT),
    K2A(486, 49, 28, 15, 0x7C, G_PRTSC, "*"),
    K2(516, 49, 28, 15, 0x69, "1", G_END),
    K2(546, 49, 28, 15, 0x72, "2", GL_DOWN),
    K2(576, 49, 28, 15, 0x7A, "3", G_PGDN),
    // row 4
    KA(2, 65, 28, 15, 0x01, "F9 "),
    KA(32, 65, 28, 15, 0x09, "F10"),
    KA(74, 65, 50, 15, 0x11, "Alt"),
    K(126, 65, 298, 15, 0x29, ""),
    KA(426, 65, 58, 15, 0x58, "CapsL"),
    K2(486, 65, 58, 15, 0x70, "0", "Ins"),
    K2(546, 65, 58, 15, 0x71, ".", "Del"),
};

const int vkb_key_count = (int) (sizeof(vkb_keys) / sizeof(vkb_keys[0]));

int vkb_width_px(void)
{
    return 636;
}
int vkb_height_px(void)
{
    return 81;
}

void vkb_key_border(const osd_fb_t *fb, int index, uint8_t color)
{
    const vkb_key_t *k = &vkb_keys[index];
    osd_border(fb, k->x, k->y, k->w, k->h, color);
}

static int str_len(const char *s)
{
    int n = 0;
    while (s[n]) {
        n++;
    }
    return n;
}

// Draw s right-aligned so its last glyph sits 3px inside the key's right edge.
static void draw_legend_right(const osd_fb_t *fb, const vkb_key_t *k, int y, const char *s)
{
    osd_draw_string(fb, k->x + k->w - 3 - str_len(s) * 8, y, s, OSD_LABEL);
}

void vkb_draw_keyboard(const osd_fb_t *fb, int selected)
{
    osd_clear(fb, OSD_BODY);
    for (int i = 0; i < vkb_key_count; i++) {
        const vkb_key_t *k = &vkb_keys[i];
        osd_fill_rect(fb, k->x + 1, k->y + 1, k->w - 2, k->h - 2, k->face);
        osd_border(fb, k->x, k->y, k->w, k->h, OSD_KEYEDGE);
        if (k->label2) {
            // Dual legend: primary top-left, secondary bottom-right. Splitting them
            // diagonally lets two glyphs share a 15px key without stacking.
            osd_draw_string(fb, k->x + 4, k->y + 3, k->label, OSD_LABEL);
            draw_legend_right(fb, k, k->y + k->h - 10, k->label2);
        } else {
            int len = str_len(k->label);
            osd_draw_string(fb, k->x + (k->w - len * 8) / 2, k->y + (k->h - 8) / 2 + 1, k->label,
                    OSD_LABEL);
        }
    }
    // The selected key is marked by recolouring its border, so cursor moves only
    // need to repaint two borders (see vkb_key_border).
    if (selected >= 0) {
        vkb_key_border(fb, selected, OSD_CURSOR);
    }
}
