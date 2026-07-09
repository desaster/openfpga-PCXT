#include "vkb_draw.h"

#include "softcpu_regs.h"

// Wait until the GPU is idle so a launch does not overwrite a command still running. The
// spin is bounded so a wedged GPU degrades to a misdrawn overlay, not a hung softcore (which
// also services the disks). The largest fill needs a few thousand iterations; this is ample.
static void gpu_wait(void)
{
    for (uint32_t spins = 0; (*GPU_STATUS & 1u) && spins < 1000000u; spins++) {
    }
}

// Clipped to the region, then drawn by the GPU as one fill command in framebuffer coordinates.
void osd_fill_rect(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color)
{
    int cx0 = x < 0 ? 0 : x;
    int cy0 = y < 0 ? 0 : y;
    int cx1 = x + w > fb->width ? fb->width : x + w;
    int cy1 = y + h > fb->height ? fb->height : y + h;
    if (cx0 >= cx1 || cy0 >= cy1) {
        return; // fully clipped
    }
    gpu_wait();
    *GPU_XY = ((uint32_t) (fb->y0 + cy0) << 16) | (uint32_t) (fb->x0 + cx0);
    *GPU_WH = ((uint32_t) (cy1 - cy0) << 16) | (uint32_t) (cx1 - cx0);
    *GPU_FILL = color & 0x0F;
}

void osd_clear(const osd_fb_t *fb, uint8_t color)
{
    osd_fill_rect(fb, 0, 0, fb->width, fb->height, color);
}

// Clear the whole framebuffer to transparent, so a previous overlay leaves no ghost.
void osd_clear_screen(void)
{
    gpu_wait();
    *GPU_XY = 0;
    *GPU_WH = ((uint32_t) OSD_FB_HEIGHT << 16) | (uint32_t) OSD_FB_WIDTH;
    *GPU_FILL = OSD_CLEAR;
}

// 1px rectangle outline drawn by the GPU as one command. rounded omits the four corner
// pixels, so it reads as a 1px-rounded key over the body. The whole rectangle must lie within
// the framebuffer (the key layout guarantees it); an out-of-bounds outline is skipped.
void osd_rect_outline(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color, int rounded)
{
    if (w < 2 || h < 2 || x < 0 || y < 0 || x + w > fb->width || y + h > fb->height) {
        return;
    }
    gpu_wait();
    *GPU_XY = ((uint32_t) (fb->y0 + y) << 16) | (uint32_t) (fb->x0 + x);
    *GPU_WH = ((uint32_t) h << 16) | (uint32_t) w;
    *GPU_OUTLINE = (rounded ? GPU_OUTLINE_ROUND : 0u) | (uint32_t) (color & 0x0F);
}

// 1px-rounded outline (the four corner pixels omitted), the key-border look.
void osd_border(const osd_fb_t *fb, int x, int y, int w, int h, uint8_t color)
{
    osd_rect_outline(fb, x, y, w, h, color, 1);
}

// One 8x8 glyph drawn by the GPU: lit pixels take the colour and the rest stay transparent,
// so the key face shows through. The whole cell must lie within the framebuffer.
void osd_draw_char(const osd_fb_t *fb, int x, int y, uint8_t ch, uint8_t color)
{
    if (x < 0 || y < 0 || x + 8 > fb->width || y + 8 > fb->height) {
        return;
    }
    gpu_wait();
    *GPU_XY = ((uint32_t) (fb->y0 + y) << 16) | (uint32_t) (fb->x0 + x);
    *GPU_CHAR = GPU_CHAR_TRANSP | ((uint32_t) (color & 0x0F) << 8) | (uint32_t) ch;
}

void osd_draw_string(const osd_fb_t *fb, int x, int y, const char *s, uint8_t color)
{
    for (; *s; s++) {
        osd_draw_char(fb, x, y, (uint8_t) *s, color);
        x += 8;
    }
}
