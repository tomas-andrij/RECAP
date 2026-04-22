//================================================================================================
// Project     : RECAP
// Module      : udp_top
// Author      : Tomas Andrijasevic
//
// Description : The UDP stack parses (RX) and builds (TX) Ethernet frames, 
//               identifies IPv4/UDP packets destined to a configurable UDP port, 
//               and generates a deterministic response packet (echo + timestamp). 
//               Non-matching packets are either dropped or passed through.
//
//               RX: RGMII -> MAC -> ETHERNET RX -> IPv4 parser -> UDP parser -> Payload AXIS -> PLUGIN
//               TX: PLUGIN -> Payload AXIS -> UDP Builder -> IPv4 Builder -> ETHERNET TX -> MAC TX -> RGMII
//
//================================================================================================

`timescale 1ns/1ps

import recap_param_pkg::*;
import recap_addr_pkg::*;
import udp_net_types_pkg::*;

module udp_top (
   input CLK_300M,
   input RESET,

   // TX: UDP -> MAC
   output logic [AXIS_DATA_WIDTH-1:0] M_AXIS_TDATA,
   output logic [AXIS_KEEP_WIDTH-1:0] M_AXIS_TKEEP,
   output logic                       M_AXIS_TVALID,
   input  logic                       M_AXIS_TREADY,
   output logic                       M_AXIS_TLAST,
   output logic                       M_AXIS_TUSER,

   // RX: MAC -> UDP
   input  logic [AXIS_DATA_WIDTH-1:0] S_AXIS_TDATA,
   input  logic [AXIS_KEEP_WIDTH-1:0] S_AXIS_TKEEP,
   input  logic                       S_AXIS_TVALID,
   output logic                       S_AXIS_TREADY,
   input  logic                       S_AXIS_TLAST,
   input  logic                       S_AXIS_TUSER
);

   logic [AXIS_DATA_WIDTH-1:0] eth2ip_rx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] eth2ip_rx_axis_tkeep;
   logic                       eth2ip_rx_axis_tvalid;
   logic                       eth2ip_rx_axis_tready;
   logic                       eth2ip_rx_axis_tlast;
   logic                       eth2ip_rx_axis_tuser;

   logic [AXIS_DATA_WIDTH-1:0] ip2udp_rx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] ip2udp_rx_axis_tkeep;
   logic                       ip2udp_rx_axis_tvalid;
   logic                       ip2udp_rx_axis_tready;
   logic                       ip2udp_rx_axis_tlast;
   logic                       ip2udp_rx_axis_tuser;

   logic [AXIS_DATA_WIDTH-1:0] udp2plugin_rx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] udp2plugin_rx_axis_tkeep;
   logic                       udp2plugin_rx_axis_tvalid;
   logic                       udp2plugin_rx_axis_tready;
   logic                       udp2plugin_rx_axis_tlast;
   logic                       udp2plugin_rx_axis_tuser;

   logic [AXIS_DATA_WIDTH-1:0] ip2eth_tx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] ip2eth_tx_axis_tkeep;
   logic                       ip2eth_tx_axis_tvalid;
   logic                       ip2eth_tx_axis_tready;
   logic                       ip2eth_tx_axis_tlast;
   logic                       ip2eth_tx_axis_tuser;

   logic [AXIS_DATA_WIDTH-1:0] udp2ip_tx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] udp2ip_tx_axis_tkeep;
   logic                       udp2ip_tx_axis_tvalid;
   logic                       udp2ip_tx_axis_tready;
   logic                       udp2ip_tx_axis_tlast;
   logic                       udp2ip_tx_axis_tuser;

   logic [AXIS_DATA_WIDTH-1:0] plugin2udp_tx_axis_tdata;
   logic [AXIS_KEEP_WIDTH-1:0] plugin2udp_tx_axis_tkeep;
   logic                       plugin2udp_tx_axis_tvalid;
   logic                       plugin2udp_tx_axis_tready;
   logic                       plugin2udp_tx_axis_tlast;
   logic                       plugin2udp_tx_axis_tuser;

   logic eth_hdr_valid;
   logic ip_hdr_valid;
   logic plugin_hdr_valid;

   pkt_hdr_t eth_hdr;
   pkt_hdr_t ip_hdr;
   pkt_hdr_t plugin_hdr;

   // Where I left off: Verified skid buffer (more than just smoke test but could be stress tested even more)
   // Could add bypass mode to it
   // Need to finish UDP stack

   // ====================== RX ====================== 
   
   eth_rx_parse i_eth_rx_parse (
      .CLK_300M (CLK_300M),
      .RESET    (RESET),

      // RX: Input from MAC
      .S_AXIS_TDATA_IN   (S_AXIS_TDATA),  // IN
      .S_AXIS_TKEEP_IN   (S_AXIS_TKEEP),  // IN
      .S_AXIS_TVALID_IN  (S_AXIS_TVALID), // IN
      .S_AXIS_TREADY_OUT (S_AXIS_TREADY), // OUT
      .S_AXIS_TLAST_IN   (S_AXIS_TLAST),  // IN
      .S_AXIS_TUSER_IN   (S_AXIS_TUSER),  // IN

      // TX: Outputs to IPv4 Parser
      .M_AXIS_TDATA_OUT  (eth2ip_rx_axis_tdata),  // OUT
      .M_AXIS_TKEEP_OUT  (eth2ip_rx_axis_tkeep),  // OUT
      .M_AXIS_TVALID_OUT (eth2ip_rx_axis_tvalid), // OUT
      .M_AXIS_TREADY_IN  (eth2ip_rx_axis_tready), // IN
      .M_AXIS_TLAST_OUT  (eth2ip_rx_axis_tlast),  // OUT
      .M_AXIS_TUSER_OUT  (eth2ip_rx_axis_tuser),  // OUT

      .HDR_OUT       (eth_hdr),
      .HDR_OUT_VALID (eth_hdr_valid)
   );

   ipv4_rx_parse i_ipv4_rx_parse (
      .CLK_300M (CLK_300M),
      .RESET    (RESET),
      
      // RX: Input from Ethernet Parser
      .S_AXIS_TDATA_IN   (eth2ip_rx_axis_tdata),  // IN
      .S_AXIS_TKEEP_IN   (eth2ip_rx_axis_tkeep),  // IN
      .S_AXIS_TVALID_IN  (eth2ip_rx_axis_tvalid), // IN
      .S_AXIS_TREADY_OUT (eth2ip_rx_axis_tready), // OUT
      .S_AXIS_TLAST_IN   (eth2ip_rx_axis_tlast),  // IN
      .S_AXIS_TUSER_IN   (eth2ip_rx_axis_tuser),  // IN

      // TX: Outputs to UDP Parser
      .M_AXIS_TDATA_OUT  (ip2udp_rx_axis_tdata),  // OUT
      .M_AXIS_TKEEP_OUT  (ip2udp_rx_axis_tkeep),  // OUT
      .M_AXIS_TVALID_OUT (ip2udp_rx_axis_tvalid), // OUT
      .M_AXIS_TREADY_IN  (ip2udp_rx_axis_tready), // IN
      .M_AXIS_TLAST_OUT  (ip2udp_rx_axis_tlast),  // OUT
      .M_AXIS_TUSER_OUT  (ip2udp_rx_axis_tuser),  // OUT

      .HDR_IN        (eth_hdr),
      .HDR_IN_VALID  (eth_hdr_valid),

      .HDR_OUT       (ip_hdr),
      .HDR_OUT_VALID (ip_hdr_valid)
   );

   udp_rx_parse i_udp_rx_parse (
      .CLK_300M (CLK_300M),
      .RESET    (RESET),
      
      // RX: Input from IPv4 Parser
      .S_AXIS_TDATA_IN   (ip2udp_rx_axis_tdata),  // IN
      .S_AXIS_TKEEP_IN   (ip2udp_rx_axis_tkeep),  // IN
      .S_AXIS_TVALID_IN  (ip2udp_rx_axis_tvalid), // IN
      .S_AXIS_TREADY_OUT (ip2udp_rx_axis_tready), // OUT
      .S_AXIS_TLAST_IN   (ip2udp_rx_axis_tlast),  // IN
      .S_AXIS_TUSER_IN   (ip2udp_rx_axis_tuser),  // IN

      // Outputs to Plugin
      .M_AXIS_TDATA_OUT  (udp2plugin_rx_axis_tdata),  // OUT
      .M_AXIS_TKEEP_OUT  (udp2plugin_rx_axis_tkeep),  // OUT
      .M_AXIS_TVALID_OUT (udp2plugin_rx_axis_tvalid), // OUT
      .M_AXIS_TREADY_IN  (udp2plugin_rx_axis_tready), // IN
      .M_AXIS_TLAST_OUT  (udp2plugin_rx_axis_tlast),  // OUT
      .M_AXIS_TUSER_OUT  (udp2plugin_rx_axis_tuser),  // OUT

      .HDR_IN        (ip_hdr),
      .HDR_IN_VALID  (ip_hdr_valid),

      .HDR_OUT       (plugin_hdr),
      .HDR_OUT_VALID (plugin_hdr_valid)
   );

   // ====================== TX ====================== 
   // eth_tx_build i_eth_tx_build ();
   // ipv4_tx_build ipv4_tx_build ();
   // udp_tx_build udp_tx_build ();
   logic tb_ready = 1'b1;
   assign plugin2udp_tx_axis_tready = tb_ready;

   plugin_slot i_plugin_slot (
      .CLK_300M (CLK_300M),
      .RESET    (RESET),

      // RX: Input from UDP Parser
      .S_AXIS_TDATA_IN   (udp2plugin_rx_axis_tdata),  // IN
      .S_AXIS_TKEEP_IN   (udp2plugin_rx_axis_tkeep),  // IN
      .S_AXIS_TVALID_IN  (udp2plugin_rx_axis_tvalid), // IN
      .S_AXIS_TREADY_OUT (udp2plugin_rx_axis_tready), // OUT
      .S_AXIS_TLAST_IN   (udp2plugin_rx_axis_tlast),  // IN
      .S_AXIS_TUSER_IN   (udp2plugin_rx_axis_tuser),  // IN

      // TX: Outputs to UDP Build
      .M_AXIS_TDATA_OUT  (plugin2udp_tx_axis_tdata),  // OUT
      .M_AXIS_TKEEP_OUT  (plugin2udp_tx_axis_tkeep),  // OUT
      .M_AXIS_TVALID_OUT (plugin2udp_tx_axis_tvalid), // OUT
      .M_AXIS_TREADY_IN  (plugin2udp_tx_axis_tready), // IN
      .M_AXIS_TLAST_OUT  (plugin2udp_tx_axis_tlast),  // OUT
      .M_AXIS_TUSER_OUT  (plugin2udp_tx_axis_tuser),  // OUT

      // plugin_hdr_valid pulses for 1 cycle at the first accepted payload beat of each packet; plugin_hdr is stable in that cycle.
      .HDR_IN       (plugin_hdr),
      .HDR_IN_VALID (plugin_hdr_valid)
   );

endmodule
