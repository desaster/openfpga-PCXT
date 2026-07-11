# PicoRV32 disk-softcore firmware build (LLVM toolchain, rv32im).
# Produces firmware.vh, the $readmemh init image for the softcore ROM.

OBJS = start.o main.o disk_tds.o fdd_service.o ide_service.o vkb_draw.o vkb_layout.o vkb_ui.o \
       settings_ui.o
DEPS = $(OBJS:.o=.d)

CC      = clang
LD      = ld.lld
OBJCOPY = llvm-objcopy
SIZE    = llvm-size

# -MMD -MP write per-object header dependencies (.d), pulled in by -include below, so
# editing a header rebuilds every object that includes it.
CFLAGS  = --target=riscv32 -march=rv32im -std=c99 -Os -mno-relax -Wall -Werror -MMD -MP
ASFLAGS = --target=riscv32 -march=rv32im -mno-relax -Wall -Werror -MMD -MP

all: firmware.vh

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
