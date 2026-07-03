#
# user core constraints
#
# Asynchronous clock-domain groups. Clocks within a group are related and timed
# normally; paths between groups are cut (their crossings are handled in RTL).
#
#   pll  (system):  [0] clk_chipset 50 MHz   [1] clk_100 (CPU)   [2] clk_sdram_ph 50@180
#   pll_video:      [0] clk_28_636 (CGA)      [1] clk_pix 14.318  [2] clk_pix_90
#   APF / bridge:   clk_74a, clk_74b, bridge_spiclk
#
# This mirrors the reference SYSTEM.sdc, which false-paths the chipset/CPU domain
# against the CGA/pixel video domain; our PLLs split along exactly that line.
#
set_clock_groups -asynchronous \
 -group { \
   ic|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { \
   ic|pll_video|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll_video|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
   ic|pll_video|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { bridge_spiclk }
