//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

//================================================================================================
// Project     : RECAP
// Module      : recap_param_pkg
// Author      : Tomas Andrijasevic
//
// Description : RECAP parameters
//================================================================================================

`ifndef RECAP_PARAM_PKG
`define RECAP_PARAM_PKG

package recap_param_pkg;

   // AXI Stream
   localparam AXIS_DATA_WIDTH = 64;
   localparam AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8;

   // AXI Lite
   localparam AXIL_ADDR_WIDTH = 32;
   localparam AXIL_DATA_WIDTH = 32;
endpackage

`endif // RECAP_PARAM_PKG
