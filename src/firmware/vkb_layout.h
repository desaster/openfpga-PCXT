#ifndef VKB_LAYOUT_H
#define VKB_LAYOUT_H

#include <stdint.h>
#include "vkb_draw.h"

// One key of the PC/XT 83-key layout: a pixel rectangle within the framebuffer.
// scancode is the Set-2 make code (KFPS2KB wants Set-2). Fields are ordered and
// sized to pack the table at 16 bytes per key; y and h fit a byte, x and w do not.
typedef struct {
    const char *label;  // primary legend: centred, or top-left when label2 is set
    const char *label2; // secondary legend, drawn bottom-right; 0 = single legend
    int16_t x, w;       // pixel rect within the framebuffer
    uint8_t y, h;
    uint8_t scancode; // Set-2 make code
    uint8_t face;     // key-face palette index (OSD_KEYFACE / OSD_KEYACCENT)
} vkb_key_t;

extern const vkb_key_t vkb_keys[];
extern const int vkb_key_count;

// Whole-keyboard pixel extent for the current geometry constants.
int vkb_width_px(void);
int vkb_height_px(void);

// Repaint one key's border in `color` (a cursor move recolours two borders).
void vkb_key_border(const osd_fb_t *fb, int index, uint8_t color);

// Draw every key into fb; selected < 0 = no cursor, else that key gets a cursor border.
void vkb_draw_keyboard(const osd_fb_t *fb, int selected);

#endif
