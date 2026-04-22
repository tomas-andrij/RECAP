//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

//================================================================================================
// Project     : RECAP
// Module      : tc_eth_sanity
// Author      : Tomas Andrijasevic
//
// Description : Generates and sends a Layer-2 Ethernet frame.
//               Ethernet header: Dst MAC | Src MAC | EtherType
//               Payload: Just 46 dummy bytes (not real ARP, not IP, not UDP)
//               Computes Ethernet FCS (CRC32) over the first 60 bytes (14+46)
//               Appends the 4-byte FCS to make the total 64 bytes
//               Sends it into the DUT PHY/GMII/RGMII RX path using phy_bfm.sv
//================================================================================================

module tc_eth_sanity;
   tb i_tb();

   // ----------------------------------------------------------------
   // TB-side CRC32 stepper (must match axis_gmii_rx eth_crc_8 instance)
   // ----------------------------------------------------------------
   logic [31:0] tb_crc_state, tb_crc_next;
   logic [7:0]  tb_crc_data;

   lfsr #(
       .LFSR_WIDTH(32),
       .LFSR_POLY(32'h04C11DB7),
       .LFSR_CONFIG("GALOIS"),
       .LFSR_FEED_FORWARD(0),
       .REVERSE(1),
       .DATA_WIDTH(8),
       .STYLE("AUTO")
   ) tb_crc_lfsr (
       .data_in (tb_crc_data),
       .state_in(tb_crc_state),
       .state_out(tb_crc_next),
       .data_out()              // unused
   );

   // ----------------------------------------------------------------
   // Test frame (60 bytes payload + 4 bytes FCS placeholder = 64 total)
   // NOTE: CRC is computed over bytes [0:59] only.
   // ----------------------------------------------------------------
   logic [7:0] test_frame_arp[] = '{
      // Ethernet Header (14 bytes)
      8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,  // Dest MAC (broadcast)
      8'h00, 8'h01, 8'h02, 8'h03, 8'h04, 8'h05,  // Src MAC
      8'h08, 8'h06,                              // EtherType (ARP)
      // Payload (46 bytes -> minimum frame size)
      8'h00, 8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07,
      8'h08, 8'h09, 8'h0A, 8'h0B, 8'h0C, 8'h0D, 8'h0E, 8'h0F,
      8'h10, 8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17,
      8'h18, 8'h19, 8'h1A, 8'h1B, 8'h1C, 8'h1D, 8'h1E, 8'h1F,
      8'h20, 8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27,
      8'h28, 8'h29, 8'h2A, 8'h2B, 8'h2C, 8'h2D,
      // FCS placeholder (4 bytes)
      8'h00, 8'h00, 8'h00, 8'h00
   };

   // ----------------------------------------------------------------
   // Helpers
   // ----------------------------------------------------------------
	function automatic logic [31:0] crc32_ethernet_reflected(
		input logic [7:0] data[],
		input int         length
	);
		logic [31:0] crc;
		int i, b;
		logic feedback;
		begin
			crc = 32'hFFFF_FFFF;
			for (i = 0; i < length; i++) begin
				for (b = 0; b < 8; b++) begin
					feedback = crc[0] ^ data[i][b];      // LSB-first
					crc = crc >> 1;
					if (feedback) crc ^= 32'hEDB88320;   // reflected poly
				end
			end
			return ~crc; // xorout
		end
	endfunction

	task automatic append_fcs_ethernet(
		inout logic [7:0] frame[],
		input int payload_len
	);
		logic [31:0] fcs;
		begin
			fcs = crc32_ethernet_reflected(frame, payload_len);

			// Ethernet wire order: least-significant byte first
			frame[payload_len+0] = fcs[7:0];
			frame[payload_len+1] = fcs[15:8];
			frame[payload_len+2] = fcs[23:16];
			frame[payload_len+3] = fcs[31:24];
		end
	endtask

   // ----------------------------------------------------------------
   // Test sequence
   // ----------------------------------------------------------------
   initial begin
      static int PAYLOAD_LEN = 60;

      $display("ETHERNET DESIGN TEST (sanity)");
      $display("[%0t] Reset...", $time);
      i_tb.tb_reset = 1;
    #1000;
      i_tb.tb_reset = 0;
      #500_000;

      i_tb.i_recap_top.rx_axis_tready = 1'b1;

      // Append correct FCS for what we are actually sending
      append_fcs_ethernet(test_frame_arp, 60);

      $display("[%0t] Sending ARP test frame...", $time);
      $display("FCS bytes = %02x %02x %02x %02x", test_frame_arp[60], test_frame_arp[61], test_frame_arp[62], test_frame_arp[63]);

      i_tb.i_phy_bfm.send_ethernet_frame(test_frame_arp, 64);

      $finish;
   end

endmodule
