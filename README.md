# [IBM PC/XT](https://en.wikipedia.org/wiki/IBM_Personal_Computer_XT) for [Analogue Pocket](https://www.analogue.co/pocket)

This is a PC/XT core for Analogue Pocket, faithfully ported from the MiSTer core.

This port was done with heavy use of AI agents. The success of this project is thanks to the hard work of the authors of the cores this port was based on, such as [@spark2k06](https://github.com/spark2k06/), [@MicroCoreLabs](https://github.com/MicroCoreLabs/) and [@kitune-san](https://github.com/kitune-san) and more (see [Credits](#credits)).

![pcxt_showcase](https://github.com/user-attachments/assets/7ef77479-f2d1-44fa-aed8-94f977082d23)

## Key features

* 8088 CPU with these speed settings: 4.77 MHz, 7.16 MHz, 9.54 MHz, and PC/AT 286 at 3.5MHz equivalent (max. speed)
* Support for IBM PCXT 5160 and clones (CGA graphics)
* Main memory 640KB + 384KB UMB memory
* Simulated Composite Video (CGA)
* ~Hercules graphics card support~ *disabled in Pocket release builds*
* EMS memory up to 2Mb
* XTIDE support
* Audio: Adlib, C/MS & speaker
* Joystick support
* Mouse support on the COM1 serial port, this works like any Microsoft mouse, you just need a driver to configure it, like CTMOUSE 1.9 (available in the hdd folder)
* Virtual Keyboard for handheld use

## Quick Start

Download and unzip the .zip from the releases to the root of your Pocket's SD card. Place floppy (.img) and HDD images (.vhd) in the Assets/pcxt/common/ folder.

## Controls:

This core can be used in handheld mode, or with an external USB keyboard and mouse via the dock.

Default controller mappings:

| Button | Configurable | Default Action                      |
| ------ | ------------ | ----------------------------------- |
| L1     | No           | Open/close virtual keyboard         |
| R1     | No           | Swap virtual keyboard position      |
| Select | Yes          | Extra Settings                      |
| Start  | Yes          | Pause/Credits                       |
| A      | Yes          | Ctrl                                |
| B      | Yes          | Alt                                 |
| X      | Yes          | Space                               |
| Y      | Yes          | Enter                               |

## Virtual Keyboard

Since the PCXT is a personal computer, a keyboard is very useful things
like entering commands DOS, editing text files or just navigating
menus in games. For this, in addition to supporting USB keyboards via the
dock, the core also provides a virtual keyboard.

| Button | Action                        |
| ------ | ----------------------------- |
| L1     | Open/close keyboard           |
| R1     | Toggle position (top/bottom)  |
| A      | Momentary press               |
| B      | Close keyboard                |
| X      | Latching/sticky press         |
| Y      | Release all latched keys      |

## Mounting the FDD image

The floppy disk image size must be compatible with the BIOS, for example:

* On IBM 5160 only 360Kb images work well.
* On Micro8088 only 720Kb and 1.44Mb images work properly.
* Other BIOS may not be compatible, such as OpenXT by Ja'akov Miles and Jon Petroski.

It is possible to use images smaller than the size supported by the BIOS, but only pre-formatted images, as it will not be possible to format them from MS-Dos.

## Credits

- [@spark2k06](https://github.com/spark2k06/) / [PCXT_MiSTer](https://github.com/spark2k06/PCXT_MiSTer) - the PCXT core this port was based on
- [@kitune-san](https://github.com/kitune-san/) / [KFPC-XT](https://github.com/kitune-san/KFPC-XT) - PC/XT chipset
- [@MicroCoreLabs](https://github.com/MicroCoreLabs/) / [MCL86](https://github.com/MicroCoreLabs/Projects) - microcode-based Intel 8088 CPU core
- [@schlae](https://github.com/schlae) / [Graphics Gremlin](https://github.com/schlae/graphics-gremlin) - CGA/Hercules video adapter
- [@sorgelig](https://github.com/sorgelig) / [MiSTer](https://github.com/mister-devel) - MiSTer FPGA project, various parts used for this core
- [@jotego](https://github.com/jotego) / [jtopl](https://github.com/jotego/jtopl) and other bits
- [@Flandango](https://github.com/Flandango) -  2-Button analog joysticks
- [Aleksander Osman](https://github.com/alfikpl) and [@sorgelig](https://github.com/sorgelig) - floppy and IDE controllers
- [Sebastian Witt](https://github.com/GHswitt) - 16750 UART (COM1 serial port)
- [TheSonders](https://github.com/TheSonders) / [MSMouseWrapper](https://github.com/TheSonders/MouseConversion/) - Microsoft serial mouse protocol reference
- [@skiselev](https://github.com/skiselev) / [8088_bios](https://github.com/skiselev/8088_bios) - open-source PC/XT BIOS
- [@agg23](https://github.com/agg23/) - Various OpenFPGA reference projects
- [@markus-zzz](https://github.com/markus-zzz/) / [MyC64](https://github.com/markus-zzz/myc64-pocket) - softcore subsystem structure
- [@dave18](https://github.com/dave18/) / [OpenFPGA_ZX-Spectrum](https://github.com/dave18/OpenFPGA_ZX-Spectrum) - softcore subsystem reference
- Joseph Gil / vgafont8 (fntcol16) - public-domain 8x8 font for the virtual keyboard
