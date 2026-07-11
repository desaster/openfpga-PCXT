#
# user core constraints
#
# Asynchronous clock-domain groups. Clocks within a group are related and timed
# normally; paths between groups are cut (their crossings are handled in RTL).
#
#   pll  (system):  [0] clk_chipset 50 MHz   [1] clk_100 (CPU)   [2] clk_sdram_ph 50@180
#   pll_video:      [0] clk_28_636 (CGA)      [1] clk_pix_cga 14.318  [2] clk_pix_cga_90
#   pll_video_hgc:  [0] clk_32_514 (HGC)      [1] clk_pix_hgc 16.257  [2] clk_pix_hgc_90
#   mf_audio_pll:   [0] audio_mclk 12.288     [1] audio_sclk 3.072
#   APF / bridge:   clk_74a, clk_74b, bridge_spiclk
#
# The chipset/CPU domain is false-pathed against both video domains; our PLLs split
# along exactly that line. The muxed back-end clock (clk_pix) carries whichever video
# PLL's clocks are selected, so each card's path into it is timed within its own
# group and the cross pair is cut.
#
# PicoRV32 softcore clock: clk_chipset (50 MHz) gated to a one-in-six pulse, about
# 8.3 MHz. It is generated in softcpu_subsystem.sv and used as a local clock, so it
# needs its own clock definition. It is cut from the other domains below; the
# crossings to clk_chipset are safe by construction, since clk_pico registers hold
# stable for a full period.
create_clock -name clk_pico -period 120.000 \
 [get_nets {core_top:ic|softcpu_subsystem:u_softcpu|clk_pico}]

set_clock_groups -asynchronous \
 -group { \
   ic|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { \
   ic|pll_video|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll_video|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll_video|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { \
   ic|pll_video_hgc|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll_video_hgc|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll_video_hgc|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { \
   ic|audio_mixer|audio_pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|audio_mixer|audio_pll|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { bridge_spiclk } \
 -group { clk_pico }
