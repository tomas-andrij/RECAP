//================================================================================================
// Project     : RECAP
// Module      : recap_addr_pkg
// Author      : Tomas Andrijasevic
//
// Description : RECAP Register addresses
//================================================================================================

`ifndef RECAP_ADDR_PKG
`define RECAP_ADDR_PKG

package recap_addr_pkg;

	// ===== Ethernet registers (0x0000_0000 - 0xXXXX_XXXX) =====
	localparam ETH_CONTROL_ADDR      = 32'h0000_0000; // RW
	localparam ETH_FRAME_STATUS_ADDR = 32'h0000_0004; // RO
	localparam RX_FRAME_COUNT        = 32'h0000_0008; // RO
	localparam RX_BYTE_COUNT         = 32'h0000_000C;
	localparam TX_FRAME_COUNT        = 32'h0000_0010;
	localparam TX_BYTE_COUNT         = 32'h0000_0014;
	localparam RX_ERR_COUNT          = 32'h0000_0018;
	localparam RX_MINLEN_COUNT       = 32'h0000_001C;
	localparam RX_MAXLEN_COUNT       = 32'h0000_0020;


endpackage

`endif // RECAP_ADDR_PKG
