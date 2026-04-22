//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

module plugin_slot (
      input logic CLK_300M,
      input logic RESET,

      // RX: Input from UDP Parser
      input  logic S_AXIS_TDATA_IN,
      input  logic S_AXIS_TKEEP_IN,
      input  logic S_AXIS_TVALID_IN,
      output logic S_AXIS_TREADY_OUT,
      input  logic S_AXIS_TLAST_IN,
      input  logic S_AXIS_TUSER_IN,

      // TX: Outputs to UDP Build
      output logic M_AXIS_TDATA_OUT,
      output logic M_AXIS_TKEEP_OUT,
      output logic M_AXIS_TVALID_OUT,
      input  logic M_AXIS_TREADY_IN,
      output logic M_AXIS_TLAST_OUT,
      output logic M_AXIS_TUSER_OUT,

      input logic HDR_IN,
      input logic HDR_IN_VALID
);

      assign S_AXIS_TREADY_OUT = M_AXIS_TREADY_IN;

endmodule
