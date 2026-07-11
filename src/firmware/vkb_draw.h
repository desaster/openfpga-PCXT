#ifndef VKB_DRAW_H
#define VKB_DRAW_H

#include <stdint.h>

// The full-screen OSD framebuffer; overlays draw into sub-regions of it.
#define OSD_FB_WIDTH  640
#define OSD_FB_HEIGHT 200

// A drawing region within the framebuffer. Coordinates passed to the primitives are relative to
// (x0, y0) and clipped to width x height, so each overlay owns a local coordinate space. Pixels
// live in the RTL GPU's framebuffer; the primitives drive it with commands, no caller buffer.
typedef struct {
    int x0, y0; // region top-left within the framebuffer
    int width;  // pixels (even)
    int height; // pixels
} osd_fb_t;

// Palette indices. 0 is transparent on the overlay (shows the picture behind).
enum {
    OSD_CLEAR = 0,
    OSD_BODY = 1,      // keyboard body / bezel
    OSD_KEYFACE = 2,   // key face
    OSD_KEYACCENT = 3, // accent key face (function / control keys)
    OSD_KEYEDGE = 4,   // key outline
    OSD_LABEL = 5,     // legend
    OSD_CURSOR = 6,    // selected-key highlight
    OSD_LATCH = 7,     // latched (held-down) key
    OSD_LATCH_CUR = 8, // latched key under the cursor
    OSD_DISABLED = 9   // dimmed text (palette entry exists in hardware; no current user)
};

void osd_fill_rect(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color);
void osd_clear(const osd_fb_t *fb, uint8_t color);

// Clear the whole framebuffer to transparent (index 0), erasing any previous overlay.
void osd_clear_screen(void);

// 1px rectangle outline drawn as one GPU command; rounded omits the four corner pixels.
void osd_rect_outline(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color, int rounded);

// 1px-rounded outline (corners omitted), which reads as a 1px-rounded key over the body.
void osd_border(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color);

// One 8x8 glyph / a string of them from the CGA font, top-left at (x, y).
void osd_draw_char(const osd_fb_t *fb, int x, int y, uint8_t ch, uint8_t color);
void osd_draw_string(const osd_fb_t *fb, int x, int y, const char *s, uint8_t color);

#endif
