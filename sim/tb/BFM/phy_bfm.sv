//================================================================================================
// Project     : RECAP
// Module      : phy_bfm
// Author      : Tomas Andrijasevic
//
// Description :
//================================================================================================
`timescale 1ns/1ps

module phy_bfm (
	// FPGA -> PHY (what FPGA TX sends to PHY)
   input  logic       bfm_rgmii_rx_clk,
   input  logic       bfm_rgmii_rx_ctl,
   input  logic [3:0] bfm_rgmii_rxd,
   
   // PHY -> FPGA (what PHY sends to FPGA RX)
   output logic       bfm_rgmii_tx_clk,
   output logic       bfm_rgmii_tx_ctl,
   output logic [3:0] bfm_rgmii_txd
);

	// Generate RGMII PHY TX CLK
	initial begin
		bfm_rgmii_tx_clk = 0;
	end
	always #8 bfm_rgmii_tx_clk = ~bfm_rgmii_tx_clk; // 125MHz
	
	// Initialize RGMII TX 
	initial begin
      bfm_rgmii_tx_ctl = 1'b0;
      bfm_rgmii_txd = 4'h0;
   end
	
	//==================================TX RGMII Byte==================================
	task automatic tx_byte_rgmii (
      input [7:0] byte_data,
      input       ctl_bit  // 1=data_valid, 0=idle
   );
      begin
         // Setup for next rising edge
         @(negedge bfm_rgmii_tx_clk);
         #1ps;
         bfm_rgmii_txd    = byte_data[3:0];   // DUT samples low nibble on posedge
         bfm_rgmii_tx_ctl = ctl_bit;

         // Setup for next falling edge
         @(posedge bfm_rgmii_tx_clk);
         #1ps;
         bfm_rgmii_txd    = byte_data[7:4];   // DUT samples high nibble on negedge
         bfm_rgmii_tx_ctl = ctl_bit;
      end
   endtask
	
	//==================================Send Ethernet Frame==================================
	task automatic send_ethernet_frame(
      input logic [7:0] packet_data [],
      input integer     packet_length
   );
      integer i;
      begin
         $display("[%0t] PHY BFM: Sending %0d byte Ethernet frame", $time, packet_length);
         
         // Send preamble (7 bytes of 0x55)
         for (i = 0; i < 7; i++) begin
            tx_byte_rgmii(8'h55, 1'b1);
         end
         
         // Send SFD (Start Frame Delimiter - 0xD5)
         tx_byte_rgmii(8'hD5, 1'b1);
         
         // Send packet data
         for (i = 0; i < packet_length; i++) begin
            tx_byte_rgmii(packet_data[i], 1'b1);
         end
         
         // Send inter-packet gap (12 bytes of idle)
         for (i = 0; i < 12; i++) begin
            tx_byte_rgmii(8'h00, 1'b0);
         end
         
         $display("[%0t] PHY BFM: Frame transmission complete", $time);
      end
   endtask
	
endmodule
