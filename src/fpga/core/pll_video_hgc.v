// PCXT Pocket Hercules video PLL.
//
// Mono-monitor pixel-domain clocks from the Analogue Pocket 74.25 MHz reference
// (clk_74b):
//   outclk_0  32.514000 MHz            HGC dot-clock domain (CHIPSET clk_vga_hgc)
//   outclk_1  16.257000 MHz            Pocket scaler pixel clock in HGC mode
//   outclk_2  16.257000 MHz  @90 deg   HGC pixel clock, DDR (video_rgb_clock_90)
//
// 16.257 MHz is the MDA/Hercules dot clock; the card logic runs at 2x with an
// internal divider, like CGA's 28.636/14.318 pair. A separate PLL because
// 16.257 MHz shares no VCO with the NTSC-derived 28.636 MHz or with 50/100 MHz.
`timescale 1ns/10ps
module pll_video_hgc (
    input  wire refclk,
    input  wire rst,
    output wire outclk_0,
    output wire outclk_1,
    output wire outclk_2,
    output wire locked
);

    altera_pll #(
        .fractional_vco_multiplier ("true"),
        .reference_clock_frequency ("74.25 MHz"),
        .operation_mode            ("normal"),
        .number_of_clocks          (3),
        .output_clock_frequency0   ("32.514000 MHz"),
        .phase_shift0              ("0 ps"),
        .duty_cycle0               (50),
        .output_clock_frequency1   ("16.257000 MHz"),
        .phase_shift1              ("0 ps"),
        .duty_cycle1               (50),
        .output_clock_frequency2   ("16.257000 MHz"),
        .phase_shift2              ("15378 ps"),
        .duty_cycle2               (50),
        .pll_type                  ("General"),
        .pll_subtype               ("General")
    ) altera_pll_i (
        .rst      (rst),
        .outclk   ({outclk_2, outclk_1, outclk_0}),
        .locked   (locked),
        .fboutclk (),
        .fbclk    (1'b0),
        .refclk   (refclk)
    );

endmodule
