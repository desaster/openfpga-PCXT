#ifndef VKB_DRAW_H
#define VKB_DRAW_H

#include <stdint.h>

// 4bpp OSD framebuffer, two pixels per byte: even x in the high nibble, odd x in
// the low nibble (matches the FPGA readout). The caller owns the pixel buffer.
typedef struct {
    uint8_t *pixels; // stride * height bytes
    int width;       // pixels (even)
    int height;      // pixels
    int stride;      // bytes per row (width / 2)
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
    OSD_LATCH_CUR = 8  // latched key under the cursor
};

void osd_set_pixel(const osd_fb_t *fb, int x, int y, uint8_t color);
void osd_fill_rect(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color);
void osd_clear(const osd_fb_t *fb, uint8_t color);

// 1px rectangle outline with the four corner pixels omitted, which reads as a
// 1px-rounded key when drawn over the body.
void osd_border(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color);

// One 8x8 glyph / a string of them from the CGA font, top-left at (x, y).
void osd_draw_char(const osd_fb_t *fb, int x, int y, uint8_t ch, uint8_t color);
void osd_draw_string(const osd_fb_t *fb, int x, int y, const char *s, uint8_t color);

#endif
