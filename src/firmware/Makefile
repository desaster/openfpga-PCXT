# PicoRV32 disk-softcore firmware build (LLVM toolchain, rv32im).
# Produces firmware.vh, the $readmemh init image for the softcore ROM.

OBJS = start.o main.o fdd_service.o ide_service.o

CC      = clang
LD      = ld.lld
OBJCOPY = llvm-objcopy

CFLAGS  = --target=riscv32 -march=rv32im -std=c99 -Os -fno-inline -mno-relax -Wall -Werror
ASFLAGS = --target=riscv32 -march=rv32im -mno-relax -Wall -Werror

all: firmware.vh

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(ASFLAGS) -c $< -o $@

firmware.elf: $(OBJS) system.ld
	$(LD) -T system.ld $(OBJS) -o $@

firmware.bin: firmware.elf
	$(OBJCOPY) --keep-section=.text --keep-section=.data --output-target=binary $< $@

firmware.vh: firmware.bin
	hexdump -v -e '4/4 "%08x " "\n"' $< > $@

clean:
	rm -f *.o firmware.elf firmware.bin firmware.vh

check-format:
	clang-format --dry-run --Werror $(wildcard *.c *.h)

.PHONY: all clean check-format
