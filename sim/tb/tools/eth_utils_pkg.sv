//================================================================================================
// Project     : RECAP
// Module      : eth_utils_pkg
// Author      : Tomas Andrijasevic
//
// Description : Tasks and Functions for Ethernet Simulation on RECAP platform
//================================================================================================
`timescale 1ns/1ps

`ifndef ETH_UTILS_PKG
`define ETH_UTILS_PKG

package eth_utils_pkg;

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

endpackage

`endif // ETH_UTILS_PKG
