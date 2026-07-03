// PCXT Pocket video PLL.
//
// Pixel-domain clocks from the Analogue Pocket 74.25 MHz reference (clk_74a):
//   outclk_0  28.636360 MHz            CGA dot-clock domain (CHIPSET clk_vga_cga)
//   outclk_1  14.318180 MHz            Pocket scaler pixel clock (video_rgb_clock)
//   outclk_2  14.318180 MHz  @90 deg   scaler pixel clock, DDR (video_rgb_clock_90)
//
// 28.63636 MHz is 2x the NTSC-derived CGA 14.31818 MHz dot clock; the scaler locks
// to whatever pixel rate we present, so 14.31818 MHz drives the video-out DDIO with
// its 90-degree companion. A separate PLL from the system one because these do not
// share a VCO with 50/100 MHz (same reason MiSTer splits pll / pll_system).
`timescale 1ns/10ps
module pll_video (
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
        .output_clock_frequency0   ("28.636360 MHz"),
        .phase_shift0              ("0 ps"),
        .duty_cycle0               (50),
        .output_clock_frequency1   ("14.318180 MHz"),
        .phase_shift1              ("0 ps"),
        .duty_cycle1               (50),
        .output_clock_frequency2   ("14.318180 MHz"),
        .phase_shift2              ("17460 ps"),
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
