#ifndef VKB_UI_H
#define VKB_UI_H

// Set up the OSD framebuffer and draw the keyboard once.
void vkb_ui_init(void);

// Poll controller 1: L1 toggles the keyboard, the D-pad moves the cursor.
void vkb_ui_tick(void);

#endif
