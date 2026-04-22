//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

//================================================================================================
// Project     : RECAP
// Module      : udp_net_types_pkg
// Author      : Tomas Andrijasevic
//
// Description : RECAP UDP net types
//================================================================================================
`timescale 1ns/1ps

`ifndef UDP_NET_TYPES_PKG
`define UDP_NET_TYPES_PKG

package udp_net_types_pkg;

   typedef struct packed {
      logic [47:0] eth_dst_mac;
      logic [47:0] eth_src_mac;
      logic [15:0] eth_type;

      logic [31:0] ip_src;
      logic [31:0] ip_dst;
      logic [7:0]  ip_proto;
      logic [15:0] ip_total_len;
      logic [3:0]  ip_ihl;

      logic [15:0] udp_src_port;
      logic [15:0] udp_dst_port;
      logic [15:0] udp_len;
      logic [15:0] udp_csum;
   } pkt_hdr_t;

endpackage

`endif // UDP_NET_TYPES_PKG
