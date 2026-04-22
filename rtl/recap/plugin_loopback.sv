//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

//================================================================================================
// Project     : RECAP
// Module      : plugin_loopback
// Author      : Tomas Andrijasevic
// Description : AXIS loopback plugin
//================================================================================================

`timescale 1ns/1ps

import recap_param_pkg::*;
import recap_addr_pkg::*;

module plugin_loopback (
   input  logic CLK_300M,
   input  logic RESET,

   // TX: user -> MAC (we drive these)
   output logic [AXIS_DATA_WIDTH-1:0] TX_AXIS_TDATA,
   output logic [AXIS_KEEP_WIDTH-1:0] TX_AXIS_TKEEP,
   output logic                       TX_AXIS_TVALID,
   input  logic                       TX_AXIS_TREADY,
   output logic                       TX_AXIS_TLAST,
   output logic                       TX_AXIS_TUSER, // must be 0 on good frames

   // RX: MAC -> user (we consume these)
   input  logic [AXIS_DATA_WIDTH-1:0] RX_AXIS_TDATA,
   input  logic [AXIS_KEEP_WIDTH-1:0] RX_AXIS_TKEEP,
   input  logic                       RX_AXIS_TVALID,
   output logic                       RX_AXIS_TREADY,
   input  logic                       RX_AXIS_TLAST,
   input  logic                       RX_AXIS_TUSER  // error indicator on RX
);

    assign RX_AXIS_TREADY = 1'b1;          // always ready
    assign TX_AXIS_TVALID = RX_AXIS_TVALID;
    assign TX_AXIS_TDATA  = RX_AXIS_TDATA;
    assign TX_AXIS_TKEEP  = RX_AXIS_TKEEP;
    assign TX_AXIS_TLAST  = RX_AXIS_TLAST;
    assign TX_AXIS_TUSER  = 1'b0;          // force good on TX

endmodule
