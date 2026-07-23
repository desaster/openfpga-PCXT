#ifndef DPAD_H
#define DPAD_H

// D-pad direction presets, chosen in the Controls submenu. Each expands to the D-pad key_cfg slots;
// the two roguelike presets also define the corner keys the eight-way resolver emits.
enum {
    DPAD_NUMPAD,      // keypad 8/2/4/6
    DPAD_NUMPAD_DIAG, // + keypad 7/9/1/3
    DPAD_ARROWS,      // E0 cursor keys
    DPAD_WASD,
    DPAD_HJKL,      // vi keys k/j/h/l
    DPAD_HJKL_YUBN, // + y/u/b/n
    DPAD_COUNT
};

// Push the chosen preset's scancodes into the softcore key_cfg file; called at boot and on change.
void dpad_apply(int preset);

#endif
