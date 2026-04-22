//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

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
