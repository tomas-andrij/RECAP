//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

//================================================================================================
// Project     : RECAP
// Module      : recap_top
// Author      : Tomas Andrijasevic
// Description : Async assert, sync deassert reset synchronizer (2 FF)
//================================================================================================

`timescale 1ns/1ps

import recap_param_pkg::*;
import recap_addr_pkg::*;

module reset_sync (
   input  logic clk,
   input  logic arst,   // async, active-high
   output logic srst    // sync, active-high
);

   (* ASYNC_REG = "TRUE" *) logic [1:0] ff;

   always_ff @(posedge clk or posedge arst) begin
      if (arst) begin
         ff <= 2'b11;
      end else begin
         ff <= {ff[0], 1'b0};
      end
   end

   assign srst = ff[1];

endmodule
