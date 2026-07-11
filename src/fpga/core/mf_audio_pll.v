// PCXT Pocket audio PLL (interface-compatible with the OpenGateware audio_mixer).
//
// Derives the audio codec clocks from the Analogue Pocket 74.25 MHz reference (clk_74b):
//   outclk_0   12.288 MHz   MCLK, 256 x 48 kHz; also clocks the filter chain
//   outclk_1    3.072 MHz   SCLK, MCLK / 4; shifts the I2S bit stream
`timescale 1ns/10ps
module mf_audio_pll (
    input  wire refclk,
    input  wire rst,
    output wire outclk_0,
    output wire outclk_1,
    output wire locked
);

    altera_pll #(
        .fractional_vco_multiplier ("true"),
        .reference_clock_frequency ("74.25 MHz"),
        .operation_mode            ("direct"),
        .number_of_clocks          (2),
        .output_clock_frequency0   ("12.288000 MHz"),
        .phase_shift0              ("0 ps"),
        .duty_cycle0               (50),
        .output_clock_frequency1   ("3.072000 MHz"),
        .phase_shift1              ("0 ps"),
        .duty_cycle1               (50),
        .pll_type                  ("General"),
        .pll_subtype               ("General")
    ) altera_pll_i (
        .rst      (rst),
        .outclk   ({outclk_1, outclk_0}),
        .locked   (locked),
        .fboutclk (),
        .fbclk    (1'b0),
        .refclk   (refclk)
    );

endmodule
