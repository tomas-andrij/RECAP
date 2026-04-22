//================================================================================================
// Project     : RECAP
// Module      : ipv4_rx_parse
// Author      : Tomas Andrijasevic
//
// Description : 
//================================================================================================
`timescale 1ns/1ps

module ipv4_rx_parse (
	input logic CLK_300M,
	input logic RESET,

	// RX: Input from Ethernet Parser
	input  logic [AXIS_DATA_WIDTH-1:0] S_AXIS_TDATA_IN,
	input  logic [AXIS_KEEP_WIDTH-1:0] S_AXIS_TKEEP_IN,
	input  logic 							  S_AXIS_TVALID_IN,
	output logic 							  S_AXIS_TREADY_OUT,
	input  logic 							  S_AXIS_TLAST_IN,
	input  logic 							  S_AXIS_TUSER_IN,

	// TX: Output to UDP Parser
	output logic [AXIS_DATA_WIDTH-1:0] M_AXIS_TDATA_OUT,
	output logic [AXIS_KEEP_WIDTH-1:0] M_AXIS_TKEEP_OUT,
	output logic 						     M_AXIS_TVALID_OUT,
	input  logic 						     M_AXIS_TREADY_IN,
	output logic 						     M_AXIS_TLAST_OUT,
	output logic 						     M_AXIS_TUSER_OUT,

	input  logic     HDR_IN_VALID,
	input  pkt_hdr_t HDR_IN,

	output logic     HDR_OUT_VALID,
	output pkt_hdr_t HDR_OUT
);

	assign S_AXIS_TREADY_OUT = M_AXIS_TREADY_IN;

endmodule
