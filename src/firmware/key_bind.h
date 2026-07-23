#ifndef KEY_BIND_H
#define KEY_BIND_H

#include <stdint.h>

// Controller-button key bindings, owned by the softcore and driven into the machine through the
// per-control key_cfg file. The seven remappable buttons; L1 is absent because it stays the fixed
// VKB toggle.
enum { BIND_A, BIND_B, BIND_X, BIND_Y, BIND_R1, BIND_SELECT, BIND_START, BIND_COUNT };

// Seed every binding to its compiled default and push it to the softcore config registers.
// Called once at boot, before the guest is released.
void key_bind_init(void);

// Restore every binding to its compiled default and push it live (Reset to Defaults).
void key_bind_reset(void);

// Rebind a button and push the change to the softcore live. code is the encoding byte (0 unmapped,
// a Set-2 make code, or a function sentinel); ext is its E0 flag.
void key_bind_set(int btn, uint8_t code, int ext);

// The raw encoding byte and E0 flag a button is bound to; used to display the row and to pack the
// binding into the settings save blob (restore via key_bind_set).
uint8_t key_bind_code(int btn);
int key_bind_ext(int btn);

// The OSD function (BTNFN_* from softcpu_regs.h) a button is bound to, or BTNFN_NONE when it is
// bound to a keyboard key or unmapped. Keyboard keys are typed by pocket_keyboard, not here.
uint8_t key_bind_function(int btn);

#endif
