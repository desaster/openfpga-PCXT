#include "vkb_draw.h"

#include "font/font_8x8.h"

void osd_set_pixel(const osd_fb_t *fb, int x, int y, uint8_t color)
{
    if (x < 0 || y < 0 || x >= fb->width || y >= fb->height) {
        return;
    }
    uint8_t *b = &fb->pixels[y * fb->stride + (x >> 1)];
    if (x & 1) {
        *b = (*b & 0xF0) | (color & 0x0F);
    } else {
        *b = (*b & 0x0F) | ((color & 0x0F) << 4);
    }
}

// Byte-wise fill: whole bytes (two pixels) for the run, with the odd leading or
// trailing pixel masked in. The rect is clipped to the buffer once, so the inner
// loop needs no per-pixel bounds checks.
void osd_fill_rect(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color)
{
    int x0 = x < 0 ? 0 : x;
    int y0 = y < 0 ? 0 : y;
    int x1 = x + w > fb->width ? fb->width : x + w;
    int y1 = y + h > fb->height ? fb->height : y + h;
    if (x0 >= x1 || y0 >= y1) {
        return; // fully clipped
    }
    uint8_t nib = color & 0x0F;
    uint8_t pair = (nib << 4) | nib;
    for (int ry = y0; ry < y1; ry++) {
        uint8_t *row = &fb->pixels[ry * fb->stride];
        int rx = x0;
        if (rx & 1) {
            row[rx >> 1] = (row[rx >> 1] & 0xF0) | nib;
            rx++;
        }
        while (rx + 1 < x1) {
            row[rx >> 1] = pair;
            rx += 2;
        }
        if (rx < x1) {
            row[rx >> 1] = (row[rx >> 1] & 0x0F) | (nib << 4);
        }
    }
}

void osd_clear(const osd_fb_t *fb, uint8_t color)
{
    uint8_t nib = color & 0x0F;
    uint8_t pair = (nib << 4) | nib;
    int n = fb->stride * fb->height;
    for (int i = 0; i < n; i++) {
        fb->pixels[i] = pair;
    }
}

// 1px outline with the four corner pixels left untouched, which reads as a
// 1px-rounded key when drawn over the body.
void osd_border(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color)
{
    for (int i = 1; i < w - 1; i++) {
        osd_set_pixel(fb, x + i, y, color);
        osd_set_pixel(fb, x + i, y + h - 1, color);
    }
    for (int i = 1; i < h - 1; i++) {
        osd_set_pixel(fb, x, y + i, color);
        osd_set_pixel(fb, x + w - 1, y + i, color);
    }
}

// One 8x8 CGA glyph: a set bit lights a pixel. Off pixels are left transparent so
// the key face shows through.
void osd_draw_char(const osd_fb_t *fb, int x, int y, uint8_t ch, uint8_t color)
{
    for (int row = 0; row < 8; row++) {
        uint8_t bits = font_8x8[ch][row];
        for (int col = 0; col < 8; col++) {
            if (bits & (0x80 >> col)) {
                osd_set_pixel(fb, x + col, y + row, color);
            }
        }
    }
}

void osd_draw_string(const osd_fb_t *fb, int x, int y, const char *s, uint8_t color)
{
    for (; *s; s++) {
        osd_draw_char(fb, x, y, (uint8_t) *s, color);
        x += 8;
    }
}
