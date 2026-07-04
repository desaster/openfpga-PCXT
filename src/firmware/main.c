// Disk-service firmware entry point.
//
// Placeholder: the PicoRV32 disk softcore RTL is not instantiated yet, so main
// just parks the CPU. The floppy service loop (poll fdd_request, read the LBA,
// pull the sector via the APF bridge, stream it into floppy.v's mgmt FIFO)
// lands with the softcore port. Kept minimal so the firmware toolchain builds
// and check-format is enforced from the start.

int main(void)
{
    for (;;) {
    }
    return 0;
}
