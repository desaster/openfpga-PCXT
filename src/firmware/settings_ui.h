#ifndef SETTINGS_UI_H
#define SETTINGS_UI_H

#include <stdint.h>

// Open the settings overlay: reset to the main menu, clear the framebuffer, and draw. Mutually
// exclusive with the virtual keyboard.
void settings_open(void);

// Redraw the settings overlay at its current menu and cursor (no reset), erasing whatever was on
// screen. Used to return from the key picker to the row it was opened from.
void settings_reopen(void);

// Raise the credits overlay (edge-armed OSD_ACTION); used by the menu action and the Start button.
void settings_show_credits(void);

// Handle one tick of controller edges while the overlay is shown: navigate submenus and cycle
// values. Returns nonzero when the user dismisses the overlay (B at the main menu).
int settings_input(uint16_t pressed);

// Load the persisted settings from the nonvolatile save (if present) and apply them; call once at
// startup, before the OSD can run. settings_service() writes any later change back into the save
// window; call it from the main loop.
void settings_load(void);
void settings_service(void);

// Flag the save dirty so settings_service() flushes it. For changes made outside this module (a
// rebind from the key picker) that must persist alongside the settings.
void settings_mark_dirty(void);

#endif
