// PCXT Pocket system PLL.
//
// Derives the core clocks from the Analogue Pocket 74.25 MHz reference (clk_74a):
//   outclk_0   50.000 MHz            chipset + SDRAM controller + XT_CE_Generator
//   outclk_1  100.000 MHz            i8088 (MCL86) CORE_CLK
//   outclk_2   50.000 MHz  @180 deg  SDRAM device clock (dram_clk), edge-centered
//
// These come from the 74.25 MHz reference via a fractional-N VCO. Quartus solves
// the M/N/C counters from the frequency strings, so retuning is a text edit. The
// outclk_2 phase is the SDRAM clock-forwarding knob for timing closure.
`timescale 1ns/10ps
module pll (
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
        .output_clock_frequency0   ("50.000000 MHz"),
        .phase_shift0              ("0 ps"),
        .duty_cycle0               (50),
        .output_clock_frequency1   ("100.000000 MHz"),
        .phase_shift1              ("0 ps"),
        .duty_cycle1               (50),
        .output_clock_frequency2   ("50.000000 MHz"),
        .phase_shift2              ("10000 ps"),
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
