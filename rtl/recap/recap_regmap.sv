//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

//================================================================================================
// Project     : RECAP
// Module      : recap_regamp
// Author      : Tomas Andrijasevic
//
// Description : Unused for now. Until UDP Stack is implemented
//================================================================================================

`timescale 1ns/1ps

import recap_param_pkg::*;
import recap_addr_pkg::*;

module recap_regmap (
   input  logic ACLK,
   input  logic ARESETN,

   //AXI-Lite slave interface
   input  logic [AXIL_ADDR_WIDTH-1:0] S_AXI_AWADDR,  // Write address channel
   input  logic                       S_AXI_AWVALID, // Write address channel
   output logic                       S_AXI_AWREADY, // Write address channel

   input  logic [AXIL_DATA_WIDTH-1:0] S_AXI_WDATA,   // Write data channel
   input  logic [3:0]                 S_AXI_WSTRB,   // Write data channel
   input  logic                       S_AXI_WVALID,  // Write data channel
   output logic                       S_AXI_WREADY,  // Write data channel

   output logic [1:0]                 S_AXI_BRESP,   // Write response channel
   output logic                       S_AXI_BVALID,  // Write response channel
   input  logic                       S_AXI_BREADY,  // Write response channel

   input  logic [AXIL_ADDR_WIDTH-1:0] S_AXI_ARADDR,  // Read address channel
   input  logic                       S_AXI_ARVALID, // Read address channel
   output logic                       S_AXI_ARREADY, // Read address channel

   output logic [AXIL_DATA_WIDTH-1:0] S_AXI_RDATA,   // Read data channel
   output logic [1:0]                 S_AXI_RRESP,   // Read data channel
   output logic                       S_AXI_RVALID,  // Read data channel
   input  logic                       S_AXI_RREADY,  // Read data channel

   //Signals to plugin core
   output logic                       START,
   output logic [AXIL_DATA_WIDTH-1:0] CONFIG_DATA,
   output logic                       CLEAR_DONE,
   input  logic                       DONE,

   //Resets
   output logic ETH_RESET,
   output logic RECAP_RESET,
   output logic PLUGIN_RESET,

   // Ethernet control signals
   output logic                  ENABLE_RX,
   output logic                  CLEAR_COUNTERS,

   // Ethernet status signals (inputs from Ethernet module)
   input  logic [15:0]           PACKET_COUNT,
   input  logic [15:0]           VALID_PACKET_COUNT,
   input  logic [15:0]           ERROR_PACKET_COUNT,
   input  logic [10:0]           LAST_PACKET_SIZE,
   input  logic                  RX_ACTIVE,
   input  logic                  PACKET_RECEIVED,
   input  logic                  PACKET_ERROR
);

   //RW registers
   logic [AXIL_DATA_WIDTH-1:0] plugin_control;
   logic [AXIL_DATA_WIDTH-1:0] plugin_config;
   logic [AXIL_DATA_WIDTH-1:0] reset_ctrl;    // [0]=plugin, [1]=recap, [2]=ethernet
   logic [AXIL_DATA_WIDTH-1:0] eth_control;   // [0]=enable_rx, [1]=clear_counters

   //RO registers
   logic [AXIL_DATA_WIDTH-1:0] plugin_status;
   logic [AXIL_DATA_WIDTH-1:0] eth_status;
   logic [AXIL_DATA_WIDTH-1:0] eth_packet_count;
   logic [AXIL_DATA_WIDTH-1:0] eth_valid_packet_count;
   logic [AXIL_DATA_WIDTH-1:0] eth_error_packet_count;
   logic [AXIL_DATA_WIDTH-1:0] eth_packet_size;

   //Read Write Signals
   logic [AXIL_ADDR_WIDTH-1:0] write_addr;
   logic [AXIL_ADDR_WIDTH-1:0] read_addr;
   logic write_en;
   logic read_en;

   localparam PLUGIN_CONTROL_ADDR     = 32'h00000000;
   localparam PLUGIN_CONFIG_ADDR      = 32'h00000004;
   localparam PLUGIN_STATUS_ADDR      = 32'h00000008;
   localparam RESET_CTRL_ADDR         = 32'h0000000C;
   localparam ETH_CONTROL_ADDR        = 32'h00000010;
   localparam ETH_STATUS_ADDR         = 32'h00000014;
   localparam ETH_PACKET_COUNT_ADDR   = 32'h00000018;
   localparam ETH_VALID_COUNT_ADDR    = 32'h0000001C;
   localparam ETH_ERROR_COUNT_ADDR    = 32'h00000020;
   localparam ETH_PACKET_SIZE_ADDR    = 32'h00000024;

   // Output wiring
   assign CONFIG_DATA = plugin_config;
   assign START = plugin_control[0];
   assign CLEAR_DONE = plugin_control[1];
   assign plugin_status = {31'd0, DONE};

   //Resets
   assign PLUGIN_RESET = reset_ctrl[0];
   assign RECAP_RESET = reset_ctrl[1];
   assign ETH_RESET = reset_ctrl[2];

   // Ethernet control outputs
   assign ENABLE_RX = eth_control[0];
   assign CLEAR_COUNTERS = eth_control[1];

   // Ethernet status registers (updated from inputs)
   assign eth_status = {26'd0, PACKET_ERROR, PACKET_RECEIVED, 1'b0, RX_ACTIVE, 1'b0, 1'b0};
   assign eth_packet_count = {16'd0, PACKET_COUNT};
   assign eth_valid_packet_count = {16'd0, VALID_PACKET_COUNT};
   assign eth_error_packet_count = {16'd0, ERROR_PACKET_COUNT};
   assign eth_packet_size = {21'd0, LAST_PACKET_SIZE};

   //One-cycle reset ctrl pulses
   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         reset_ctrl <= 0;
         eth_control <= 32'h00000001; // Enable RX by default
      end else begin
         if (write_en && write_addr == RESET_CTRL_ADDR)
            reset_ctrl <= S_AXI_WDATA[2:0];
         else
            reset_ctrl <= 0; // auto-clear after 1 cycle

         // Handle clear_counters as one-shot pulse
         if (write_en && write_addr == ETH_CONTROL_ADDR) begin
            eth_control[0] <= S_AXI_WDATA[0]; // enable_rx (persistent)
            eth_control[1] <= S_AXI_WDATA[1]; // clear_counters (one-shot)
         end else begin
            eth_control[1] <= 1'b0; // auto-clear clear_counters
         end
      end
   end

   //------------------------------------------------------------------
   //                     WRITE ADDRESS CHANNEL
   //------------------------------------------------------------------

   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         S_AXI_AWREADY <= 1'b0;
      end else begin
         if (!S_AXI_AWREADY && S_AXI_AWVALID) begin
            S_AXI_AWREADY <= 1'b1;
         end else if (S_AXI_AWREADY && S_AXI_AWVALID) begin
            S_AXI_AWREADY <= 1'b0;
         end
      end
   end

   //Get AXI write address when write address is valid (S_AXI_AWVALID = 1)
   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         write_addr <= 0;
      end else begin
         if (S_AXI_AWVALID && S_AXI_AWREADY) begin
            write_addr <= S_AXI_AWADDR;
         end
      end
   end

   //------------------------------------------------------------------
   //                     WRITE DATA CHANNEL
   //------------------------------------------------------------------

   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         S_AXI_WREADY <= 1'b0;
         write_en <= 1'b0;
      end else begin
         if (!S_AXI_WREADY && S_AXI_WVALID) begin
            S_AXI_WREADY <= 1'b1;
            write_en     <= 1'b1; // assert for one cycle
         end else begin
            S_AXI_WREADY <= 1'b0;
            write_en     <= 1'b0; // clear
         end
      end
   end

   //Write data into registers
   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         plugin_control <= 'b0;
         plugin_config <= 'b0;
      end else begin
         if (write_en) begin
            case (write_addr)
               PLUGIN_CONTROL_ADDR: plugin_control <= S_AXI_WDATA;
               PLUGIN_CONFIG_ADDR : plugin_config  <= S_AXI_WDATA;
               // ETH_CONTROL_ADDR handled in separate always block above
               default: ;
            endcase
         end
      end
   end

   //------------------------------------------------------------------
   //                     WRITE RESPONSE CHANNEL
   //------------------------------------------------------------------

   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         S_AXI_BRESP <= 2'b00;
         S_AXI_BVALID <= 1'b0;
      end else begin
         if (write_en && !S_AXI_BVALID) begin
            S_AXI_BVALID <= 1'b1;
            S_AXI_BRESP <= 2'b00;
         end else if (S_AXI_BVALID && S_AXI_BREADY) begin
            S_AXI_BVALID <= 1'b0;
         end
      end
   end

   //------------------------------------------------------------------
   //                     READ ADDRESS CHANNEL
   //------------------------------------------------------------------

   //Assert arready when data is ready for output (read_en)
   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         S_AXI_ARREADY <= 1'b0;
      end else begin
         if (!S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID) begin
            S_AXI_ARREADY <= 1'b1;
         end else begin
            S_AXI_ARREADY <= 1'b0;
         end
      end
   end

   //Setup AXI read address when read address is valid (S_AXI_ARVALID = 1)
   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         read_addr <= 'b0;
      end else begin
         if (S_AXI_ARVALID && S_AXI_ARREADY) begin
            read_addr <= S_AXI_ARADDR;
         end
      end
   end

   //------------------------------------------------------------------
   //                     READ DATA CHANNEL
   //------------------------------------------------------------------

   assign read_en = S_AXI_ARVALID && S_AXI_ARREADY && !S_AXI_RVALID;

   //The AXI master is allowed to raise rready any time, we must guarantee that rdata is valid when we assert rvalid.
   always_ff @(posedge ACLK) begin
      if (!ARESETN) begin
         S_AXI_RVALID <= 1'b0;
         S_AXI_RRESP <= 2'b00;
         S_AXI_RDATA <= 'b0;
      end else begin
         if (read_en) begin
            case (read_addr)
               PLUGIN_CONTROL_ADDR  : S_AXI_RDATA <= plugin_control;
               PLUGIN_CONFIG_ADDR   : S_AXI_RDATA <= plugin_config;
               PLUGIN_STATUS_ADDR   : S_AXI_RDATA <= plugin_status;
               RESET_CTRL_ADDR      : S_AXI_RDATA <= reset_ctrl;
               ETH_CONTROL_ADDR     : S_AXI_RDATA <= eth_control;
               ETH_STATUS_ADDR      : S_AXI_RDATA <= eth_status;
               ETH_PACKET_COUNT_ADDR: S_AXI_RDATA <= eth_packet_count;
               ETH_VALID_COUNT_ADDR : S_AXI_RDATA <= eth_valid_packet_count;
               ETH_ERROR_COUNT_ADDR : S_AXI_RDATA <= eth_error_packet_count;
               ETH_PACKET_SIZE_ADDR : S_AXI_RDATA <= eth_packet_size;
               default: S_AXI_RDATA <= 32'hDEADBEEF;
            endcase
            S_AXI_RVALID <= 1'b1; //Now assert rvalid
         end else if (S_AXI_RVALID && S_AXI_RREADY) begin //Wait for Master to assert rready, then bring down rvalid
            S_AXI_RVALID <= 0;
         end
      end
   end

endmodule
