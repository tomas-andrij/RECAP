//================================================================================================
// Project     : RECAP
// Module      : recap_top
// Author      : Tomas Andrijasevic

// Description : Top module for RECAP
//================================================================================================
`timescale 1ns/1ps

import recap_param_pkg::*;
import recap_addr_pkg::*;

module recap_top (
   // Genesys 2 200 MHz LVDS clock (names match XDC)
   input  logic sysclk_p,
   input  logic sysclk_n,

   // SW0 on board reset (active-high) 
   input  logic sw_reset,

   // RGMII interface to on-board PHY
   input  logic        i_rgmii_rx_clk,
   input  logic        i_rgmii_rx_ctl,
   input  logic [3:0]  i_rgmii_rxd,
   output logic        o_rgmii_tx_clk,
   output logic        o_rgmii_tx_ctl,
   output logic [3:0]  o_rgmii_txd,

   // MDIO
   output logic        mdio_mdc,
   inout  wire         mdio_mdio_io,   // true bidir -> keep as wire

   // PHY reset (active-low)
   output logic        phy_rst_n,

   //SIM ONLY
   input logic clk_125m,
   input logic clk_125m_90,
   input logic clk_300m
);

   // Enable for synthesis | Not used in simulation
   /*
   //Clocking: LVDS 200 MHz -> clk_wiz (125 + 300 MHz)
   logic clk_200m_ibuf;
   IBUFGDS #(
      .DIFF_TERM("TRUE"), 
      .IBUF_LOW_PWR("FALSE")
   ) i_sysclk_ibuf (
      .I (sysclk_p),
      .IB(sysclk_n),
      .O (clk_200m_ibuf)
   );
   */

   // Synthesis
   //logic clk_125m;
   //logic clk_300m; 
   //logic clk_125m_90; 
   logic mmcm_locked;

   logic clk_wiz_reset = sw_reset;  // hold MMCM in reset when switch is ON

   /*
   clk_wiz_0 i_clk_wiz (
      .clk_in1 (clk_200m_ibuf),
      .reset   (clk_wiz_reset),
      .clk_out1(clk_125m),
      .clk_out2(clk_300m),
      .clk_out3(clk_125m_90),
      .locked  (mmcm_locked)
   );
   */

   `ifdef SIMULATION
      assign mmcm_locked = 1'b1;
   `else
      // mmcm_locked comes from clk_wiz in hardware
   `endif

   // Global reset: async assert, sync deassert per domain
   logic arst_any;
   logic rst_125m, rst_300m;

   assign arst_any = sw_reset | ~mmcm_locked;

   reset_sync i_rst_125m (
      .clk(clk_125m), 
      .arst(arst_any), 
      .srst(rst_125m)
   );

   reset_sync i_rst_300m (
      .clk(clk_300m), 
      .arst(arst_any), 
      .srst(rst_300m)
   );

   // PHY reset (active-low), ~16 ms after lock (in 125 MHz domain)
   localparam int PHY_RST_HOLD_CYC = 2_000_000; // ~16 ms @125 MHz
   localparam int PHY_CNT_W = $clog2(PHY_RST_HOLD_CYC+1);

   logic [PHY_CNT_W-1:0] phy_cnt = '0;
   logic                 phy_rstn_int = 1'b0;

   always_ff @(posedge clk_125m or posedge arst_any) begin
      if (arst_any) begin
         phy_cnt     <= '0;
         phy_rstn_int <= 1'b0;
      end else begin
         if (phy_cnt != PHY_RST_HOLD_CYC[PHY_CNT_W-1:0]) begin
            phy_cnt     <= phy_cnt + 1'b1;
            phy_rstn_int <= 1'b0;
         end else begin
            phy_rstn_int <= 1'b1;
         end
      end
   end

   assign phy_rst_n = phy_rstn_int;

   // AXI-Stream between MAC and plugin
   localparam int AXIS_DATA_WIDTH = 64;
   localparam int AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8;

   logic [AXIS_DATA_WIDTH-1:0] tx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] tx_axis_tkeep;
   logic                       tx_axis_tvalid, tx_axis_tready, tx_axis_tlast, tx_axis_tuser;

   logic [AXIS_DATA_WIDTH-1:0] rx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] rx_axis_tkeep;
   logic                       rx_axis_tvalid, rx_axis_tready, rx_axis_tlast, rx_axis_tuser;

   // Status
   logic        tx_error_underflow;
   logic        tx_fifo_overflow, tx_fifo_bad_frame, tx_fifo_good_frame;
   logic        rx_error_bad_frame, rx_error_bad_fcs;
   logic        rx_fifo_overflow, rx_fifo_bad_frame, rx_fifo_good_frame;
   logic [1:0]  speed;

   // Config
   logic [7:0]  cfg_ifg       = 8'd12;
   logic        cfg_tx_enable = 1'b1;
   logic        cfg_rx_enable = 1'b1;


   // MAC + RGMII FIFO (Alex Forencich)
   eth_mac_1g_rgmii_fifo #(
      .TARGET("XILINX"),
      .IODDR_STYLE("IODDR"),
      .CLOCK_INPUT_STYLE("BUFR"),
      .USE_CLK90("FALSE"),
      .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
      .AXIS_KEEP_ENABLE(1),
      .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
      .ENABLE_PADDING(1),
      .MIN_FRAME_LENGTH(64),
      .TX_FIFO_DEPTH(4096),
      .TX_FIFO_RAM_PIPELINE(1),
      .TX_FRAME_FIFO(1),
      .TX_DROP_OVERSIZE_FRAME(1),
      .TX_DROP_BAD_FRAME(1),
      .TX_DROP_WHEN_FULL(0),
      .RX_FIFO_DEPTH(4096),
      .RX_FIFO_RAM_PIPELINE(1),
      .RX_FRAME_FIFO(1),
      .RX_DROP_OVERSIZE_FRAME(1),
      .RX_DROP_BAD_FRAME(0),
      .RX_DROP_WHEN_FULL(0)
   ) i_eth_mac_1g_rgmii_fifo (
      // Clocks/Resets
      .gtx_clk    (clk_125m),
      .gtx_clk90  (clk_125m_90),
      .gtx_rst    (rst_125m),
      .logic_clk  (clk_300m),
      .logic_rst  (rst_300m),

      // User AXIS TX
      .tx_axis_tdata (tx_axis_tdata),
      .tx_axis_tkeep (tx_axis_tkeep),
      .tx_axis_tvalid(tx_axis_tvalid),
      .tx_axis_tready(tx_axis_tready),
      .tx_axis_tlast (tx_axis_tlast),
      .tx_axis_tuser (tx_axis_tuser),

      // User AXIS RX
      .rx_axis_tdata (rx_axis_tdata),
      .rx_axis_tkeep (rx_axis_tkeep),
      .rx_axis_tvalid(rx_axis_tvalid),
      .rx_axis_tready(rx_axis_tready),
      .rx_axis_tlast (rx_axis_tlast),
      .rx_axis_tuser (rx_axis_tuser),

      // RGMII to PHY
      .rgmii_rx_clk (i_rgmii_rx_clk),
      .rgmii_rxd    (i_rgmii_rxd),
      .rgmii_rx_ctl (i_rgmii_rx_ctl),
      .rgmii_tx_clk (o_rgmii_tx_clk),
      .rgmii_txd    (o_rgmii_txd),
      .rgmii_tx_ctl (o_rgmii_tx_ctl),

      // Status
      .tx_error_underflow(tx_error_underflow),
      .tx_fifo_overflow  (tx_fifo_overflow),
      .tx_fifo_bad_frame (tx_fifo_bad_frame),
      .tx_fifo_good_frame(tx_fifo_good_frame),
      .rx_error_bad_frame(rx_error_bad_frame),
      .rx_error_bad_fcs  (rx_error_bad_fcs),
      .rx_fifo_overflow  (rx_fifo_overflow),
      .rx_fifo_bad_frame (rx_fifo_bad_frame),
      .rx_fifo_good_frame(rx_fifo_good_frame),
      .speed             (speed),

      // Config
      .cfg_ifg       (cfg_ifg),
      .cfg_tx_enable (cfg_tx_enable),
      .cfg_rx_enable (cfg_rx_enable)
   );
   /*
   // Simple loopback plugin @300 MHz
   plugin_loopback #(
      .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
      .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH)
   ) i_plugin_loopback (
      .CLK_300M(clk_300m),
      .RESET   (rst_300m),

      // TX: user -> MAC
      .TX_AXIS_TDATA (tx_axis_tdata),
      .TX_AXIS_TKEEP (tx_axis_tkeep),
      .TX_AXIS_TVALID(tx_axis_tvalid),
      .TX_AXIS_TREADY(tx_axis_tready),
      .TX_AXIS_TLAST (tx_axis_tlast),
      .TX_AXIS_TUSER (tx_axis_tuser),

      // RX: MAC -> user
      .RX_AXIS_TDATA (rx_axis_tdata),
      .RX_AXIS_TKEEP (rx_axis_tkeep),
      .RX_AXIS_TVALID(rx_axis_tvalid),
      .RX_AXIS_TREADY(rx_axis_tready),
      .RX_AXIS_TLAST (rx_axis_tlast),
      .RX_AXIS_TUSER (rx_axis_tuser)
   );*/

   udp_top i_udp_top (
      .CLK_300M(clk_300m),
      .RESET   (rst_300m),

      // TX: user -> MAC
      .M_AXIS_TDATA (tx_axis_tdata),
      .M_AXIS_TKEEP (tx_axis_tkeep),
      .M_AXIS_TVALID(tx_axis_tvalid),
      .M_AXIS_TREADY(tx_axis_tready),
      .M_AXIS_TLAST (tx_axis_tlast),
      .M_AXIS_TUSER (tx_axis_tuser),

      // RX: MAC -> user
      .S_AXIS_TDATA (rx_axis_tdata),
      .S_AXIS_TKEEP (rx_axis_tkeep),
      .S_AXIS_TVALID(rx_axis_tvalid),
      .S_AXIS_TREADY(rx_axis_tready),
      .S_AXIS_TLAST (rx_axis_tlast),
      .S_AXIS_TUSER (rx_axis_tuser)
   );

   // MDIO idle (hook your MDIO master here)
   assign mdio_mdc     = 1'b0;
   // mdio_mdio_io: leave Z unless to implement a master

   // ---------- DEBUG ALIASES (clk_300m domain) ----------
   (* mark_debug = "true" *) logic        dbg_rx_tvalid;  assign dbg_rx_tvalid  = rx_axis_tvalid;
   (* mark_debug = "true" *) logic        dbg_rx_tready;  assign dbg_rx_tready  = rx_axis_tready;
   (* mark_debug = "true" *) logic        dbg_rx_tlast;   assign dbg_rx_tlast   = rx_axis_tlast;
   (* mark_debug = "true" *) logic        dbg_rx_tuser;   assign dbg_rx_tuser   = rx_axis_tuser;
   (* mark_debug = "true" *) logic [7:0]  dbg_rx_tkeep;   assign dbg_rx_tkeep   = rx_axis_tkeep;
   (* mark_debug = "true" *) logic [63:0] dbg_rx_tdata;   assign dbg_rx_tdata   = rx_axis_tdata;

   (* mark_debug = "true" *) logic        dbg_tx_tvalid;  assign dbg_tx_tvalid  = tx_axis_tvalid;
   (* mark_debug = "true" *) logic        dbg_tx_tready;  assign dbg_tx_tready  = tx_axis_tready;
   (* mark_debug = "true" *) logic        dbg_tx_tlast;   assign dbg_tx_tlast   = tx_axis_tlast;
   (* mark_debug = "true" *) logic        dbg_tx_tuser;   assign dbg_tx_tuser   = tx_axis_tuser;
   (* mark_debug = "true" *) logic [7:0]  dbg_tx_tkeep;   assign dbg_tx_tkeep   = tx_axis_tkeep;
   (* mark_debug = "true" *) logic [63:0] dbg_tx_tdata;   assign dbg_tx_tdata   = tx_axis_tdata;

   (* mark_debug = "true" *) logic        dbg_rx_good;    assign dbg_rx_good    = rx_fifo_good_frame;
   (* mark_debug = "true" *) logic        dbg_rx_bad;     assign dbg_rx_bad     = rx_fifo_bad_frame;
   (* mark_debug = "true" *) logic        dbg_tx_good;    assign dbg_tx_good    = tx_fifo_good_frame;
   (* mark_debug = "true" *) logic        dbg_tx_under;   assign dbg_tx_under   = tx_error_underflow;

   (* mark_debug = "true" *) logic [1:0]  dbg_speed;      assign dbg_speed      = speed;
   (* mark_debug = "true" *) logic        dbg_rst_300m;   assign dbg_rst_300m   = rst_300m;
   
   (* mark_debug = "true" *) logic dbg_rx_err_fcs;  assign dbg_rx_err_fcs  = rx_error_bad_fcs;
   (* mark_debug = "true" *) logic dbg_rx_err_frm;  assign dbg_rx_err_frm  = rx_error_bad_frame;
    
   (* mark_debug = "true" *) wire [3:0] dbg_rgmii_rxd  = i_rgmii_rxd;
   (* mark_debug = "true" *) wire       dbg_rgmii_rctl = i_rgmii_rx_ctl;

endmodule
