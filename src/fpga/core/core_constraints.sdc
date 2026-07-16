#
# user core constraints
#
# Asynchronous clock-domain groups. Clocks within a group are related and timed
# normally; paths between groups are cut (their crossings are handled in RTL).
#
#   pll (system):   [0] clk_chipset 42.95   [1] clk_core 85.9 (CPU)  [2] clk_sdram_ph 42.95@180
#                   [3] clk_28_636 (CGA)    [4] clk_pix_cga 14.318   [5] clk_pix_cga_90
#   mf_audio_pll:   [0] audio_mclk 12.288   [1] audio_sclk 3.072
#   APF / bridge:   clk_74a, clk_74b, bridge_spiclk
#
# One VCO feeds the CPU, chipset and CGA video, so they are mutually synchronous and
# timed as a single group. The muxed back-end clock (clk_pix) is derived from a PLL
# output in that group, so it is intra-group too. The cut boundaries are the inherent
# Pocket bridge clocks, the audio PLL, and the gated softcore clock (clk_pico).
#
# PicoRV32 softcore clock: clk_chipset (42.95 MHz) gated to one pulse in six (~7.16 MHz),
# from softcpu_subsystem.sv. A generated clock of clk_chipset, kept in its group so the
# clk_pico <-> clk_chipset crossings are timed rather than cut.
create_generated_clock -name clk_pico -divide_by 6 \
 -source [get_pins {ic|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
 [get_nets {core_top:ic|softcpu_subsystem:u_softcpu|clk_pico}]

set_clock_groups -asynchronous \
 -group { \
   ic|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[5].gpll~PLL_OUTPUT_COUNTER|divclk \
   clk_pico } \
 -group { \
   ic|audio_mixer|audio_pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|audio_mixer|audio_pll|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { bridge_spiclk }

# clk_pico holds each value six clk_chipset cycles, so the clk_pico -> clk_chipset crossing
# has a six-cycle window (the reverse captures on clk_pico, so one cycle already suffices).
set_multicycle_path -setup -end 6 \
 -from [get_clocks clk_pico] \
 -to   [get_clocks {ic|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_multicycle_path -hold -end 5 \
 -from [get_clocks clk_pico] \
 -to   [get_clocks {ic|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
