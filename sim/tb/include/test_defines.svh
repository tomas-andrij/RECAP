//================================================================================================
// Project     : RECAP
// Module      : test_defines
// Author      : Tomas Andrijasevic
//
// Description : Macros for RECAP testbench environment
//================================================================================================

`ifndef TEST_DEFINES_SVH
`define TEST_DEFINES_SVH

`define tb           i_tb
`define recap       `tb.i_recap_top
`define udp         `recap.i_udp_top
`define phy         `tb.i_phy_bfm
`define skid_buffer `udp.i_eth_rx_parse.i_axis_skid_buffer

`endif
