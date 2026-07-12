# PicoRV32 disk-softcore firmware build (LLVM toolchain, rv32im).
# Produces firmware.vh, the $readmemh init image for the softcore ROM.

OBJS = start.o main.o disk_tds.o fdd_service.o ide_service.o vkb_draw.o vkb_layout.o vkb_ui.o \
       settings_ui.o
DEPS = $(OBJS:.o=.d)

CC      = clang
LD      = ld.lld
OBJCOPY = llvm-objcopy
SIZE    = llvm-size

# Hardware feature macros (ENABLE_*) come from the FPGA build config, so the menu
# code always compiles against the feature set of the bitstream it runs in.
# -Wundef makes an #if on a macro that failed to arrive a hard error, not a silent 0.
HW_CONFIG   = ../fpga/config.tcl
HW_DEFINES := $(addprefix -D,$(shell sed -n 's/.*VERILOG_MACRO "\(.*\)"/\1/p' $(HW_CONFIG)))

# -MMD -MP write per-object header dependencies (.d), pulled in by -include below, so
# editing a header rebuilds every object that includes it.
CFLAGS  = --target=riscv32 -march=rv32im -std=c99 -Os -mno-relax -Wall -Werror -Wundef -MMD -MP $(HW_DEFINES)
ASFLAGS = --target=riscv32 -march=rv32im -mno-relax -Wall -Werror -MMD -MP

all: firmware.vh

# The -D values are baked into every object, so a config change rebuilds them all.
$(OBJS): $(HW_CONFIG)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(ASFLAGS) -c $< -o $@

firmware.elf: $(OBJS) system.ld
	$(LD) -T system.ld $(OBJS) -o $@
	$(SIZE) $@

firmware.bin: firmware.elf
	$(OBJCOPY) --keep-section=.text --keep-section=.data --output-target=binary $< $@

firmware.vh: firmware.bin
	hexdump -v -e '4/4 "%08x " "\n"' $< > $@

clean:
	rm -f *.o *.d firmware.elf firmware.bin firmware.vh

check-format:
	clang-format --dry-run --Werror $(wildcard *.c *.h)

-include $(DEPS)

.PHONY: all clean check-format
