//================================================================================================
// Project     : RECAP
// Module      : eth_rx_parse
// Author      : Tomas Andrijasevic
//
// Description : Ethernet RX parser stage with an AXI-Stream skid buffer on the MAC input.
//
//               This module forwards the buffered AXI-Stream data to the next parser stage
//               while simultaneously extracting the 14-byte Ethernet header
//               (destination MAC, source MAC, and EtherType).
//
//               Header extraction only advances when a buffered AXI-Stream beat is actually
//               accepted by downstream logic, so the local parser state stays aligned with
//               the forwarded stream under backpressure.
//================================================================================================

`timescale 1ns/1ps

import recap_param_pkg::*;
import recap_addr_pkg::*;
import udp_net_types_pkg::*;

module eth_rx_parse_fsm (
	input logic CLK_300M,
	input logic RESET,

	// RX: MAC -> UDP
	input  logic [AXIS_DATA_WIDTH-1:0] S_AXIS_TDATA_IN,
	input  logic [AXIS_KEEP_WIDTH-1:0] S_AXIS_TKEEP_IN,
	input  logic 							  S_AXIS_TVALID_IN,
	output logic 							  S_AXIS_TREADY_OUT,
	input  logic 							  S_AXIS_TLAST_IN,
	input  logic 							  S_AXIS_TUSER_IN,

	// TX: Outputs to IPv4 Parser
	output logic [AXIS_DATA_WIDTH-1:0] M_AXIS_TDATA_OUT,
	output logic [AXIS_KEEP_WIDTH-1:0] M_AXIS_TKEEP_OUT,
	output logic 						     M_AXIS_TVALID_OUT,
	input  logic 						     M_AXIS_TREADY_IN,
	output logic 						     M_AXIS_TLAST_OUT,
	output logic 						     M_AXIS_TUSER_OUT,

	output logic     HDR_OUT_VALID,
	output pkt_hdr_t HDR_OUT
);

	// Skid buffered AXIS from MAC
	logic [AXIS_DATA_WIDTH-1:0] axis_buf_tdata;
	logic [AXIS_KEEP_WIDTH-1:0] axis_buf_tkeep;
	logic 						    axis_buf_tvalid;
	logic 							 axis_buf_tlast;
   logic 							 axis_buf_tuser;
   logic 							 axis_buf_xfer;
	logic [AXIS_DATA_WIDTH-1:0] out_tdata;
	logic [AXIS_KEEP_WIDTH-1:0] out_tkeep;

	logic [7:0] axis_byte [0:7]; // Assuming byte 0 is TDATA[7:0]
	logic [4:0] hdr_byte_idx;
	logic in_frame;

	// 		    curr bytes 0..5 	 prev bytes 6..7
	out_tdata = {curr_tdata[47:0], prev_tdata[63:48]};
	out_tkeep = {curr_tkeep[5:0],  prev_tkeep[7:6]};

	typedef enum logic [1:0] {
		IDLE,
		HEADER,
		ALIGN,
		PAYLOAD
	} state_t;

	state_t state;
	state_t next_state;

	// A beat is consumed locally when skid buffer outputs valid high && downstream ready is high
	assign axis_buf_xfer = axis_buf_tvalid && M_AXIS_TREADY_IN;

	axis_skid_buffer #(
		.DATA_WIDTH(AXIS_DATA_WIDTH),
		.KEEP_WIDTH(AXIS_KEEP_WIDTH),
		.USER_WIDTH(1)
	) i_axis_skid_buffer (
		.CLK   (CLK_300M),
		.RESET (RESET),

		.S_AXIS_TDATA_IN   (S_AXIS_TDATA_IN),
		.S_AXIS_TKEEP_IN   (S_AXIS_TKEEP_IN),
		.S_AXIS_TVALID_IN  (S_AXIS_TVALID_IN),
		.S_AXIS_TREADY_OUT (S_AXIS_TREADY_OUT),
		.S_AXIS_TLAST_IN   (S_AXIS_TLAST_IN),
		.S_AXIS_TUSER_IN   (S_AXIS_TUSER_IN),

		.M_AXIS_TDATA_OUT  (axis_buf_tdata),
		.M_AXIS_TKEEP_OUT  (axis_buf_tkeep),
		.M_AXIS_TVALID_OUT (axis_buf_tvalid),
		.M_AXIS_TREADY_IN  (M_AXIS_TREADY_IN),  // Direct ready signal from downstream
		.M_AXIS_TLAST_OUT  (axis_buf_tlast),
		.M_AXIS_TUSER_OUT  (axis_buf_tuser)
	);

	always_comb begin: Datapath
		for (int i = 0; i < 8; i++) begin
			axis_byte[i] = axis_buf_tdata[i*8 +: 8];
		end

		if (stream_data_en) begin
			M_AXIS_TDATA_OUT  = axis_buf_tdata;
			M_AXIS_TKEEP_OUT  = axis_buf_tkeep;
			M_AXIS_TVALID_OUT = axis_buf_tvalid;
			M_AXIS_TLAST_OUT  = axis_buf_tlast;
			M_AXIS_TUSER_OUT  = axis_buf_tuser;
		end
	end

	always_ff @(posedge CLK_300M) begin: FSM_Output
		if (RESET) begin
			hdr_byte_idx <= '0;
			HDR_OUT <= '0;
			HDR_OUT_VALID<= 1'b0;
		end else begin
			state <= next_state;

			case (state) begin
				IDLE: begin
					hdr_byte_idx <= '0;
					HDR_OUT <= '0;
					HDR_OUT_VALID <= 1'b0;
				end

				HEADER: begin
					// Header capture only until 14 bytes
					if (hdr_byte_idx < 14) begin
						int unsigned idx;
						idx = hdr_byte_idx;

						for (int i=0; i<8; i++) begin
							if (axis_buf_tkeep[i] && (idx < 14)) begin
								unique case (idx)
									0:  HDR_OUT.eth_dst_mac[47:40] <= axis_byte[i];
									1:  HDR_OUT.eth_dst_mac[39:32] <= axis_byte[i];
									2:  HDR_OUT.eth_dst_mac[31:24] <= axis_byte[i];
									3:  HDR_OUT.eth_dst_mac[23:16] <= axis_byte[i];
									4:  HDR_OUT.eth_dst_mac[15:8]  <= axis_byte[i];
									5:  HDR_OUT.eth_dst_mac[7:0]   <= axis_byte[i];
									6:  HDR_OUT.eth_src_mac[47:40] <= axis_byte[i];
									7:  HDR_OUT.eth_src_mac[39:32] <= axis_byte[i];
									8:  HDR_OUT.eth_src_mac[31:24] <= axis_byte[i];
									9:  HDR_OUT.eth_src_mac[23:16] <= axis_byte[i];
									10: HDR_OUT.eth_src_mac[15:8]  <= axis_byte[i];
									11: HDR_OUT.eth_src_mac[7:0]   <= axis_byte[i];
									12: HDR_OUT.eth_type[15:8]     <= axis_byte[i];
									13: begin
										HDR_OUT.eth_type[7:0] <= axis_byte[i];
										HDR_OUT_VALID         <= 1'b1;
									end
									default: ;
								endcase
								idx++;
							end
						end

						hdr_byte_idx <= idx[4:0];
					end
				end

				ALIGN: begin
					valid_beat <= 1'b0;

					if (byte_cnt == 7) begin

					end
				end

				PAYLOAD: begin

				end

				default: begin
					hdr_byte_idx <= '0;
					HDR_OUT <= '0;
					HDR_OUT_VALID <= 1'b0;
				end
			end
		end
	end

	always_comb begin: FSM_Next_State
		case (state)
			IDLE: begin
				if (axis_buf_xfer && !in_frame)  begin
					next_state = HEADER;
					in_frame = 1'b1;
				end
			end

			HEADER: begin
				if (hdr_byte_idx == 13) begin
					next_state = ALIGN;
				end
			end

			ALIGN: begin

			end

			PAYLOAD: begin
				if (axis_buf_tlast) begin
					next_state = IDLE;
					in_frame = 1'b0;
				end

				stream_data_en = 1'b1;
			end

			default: begin
				next_state = IDLE;
				in_frame = 1'b0;
			end
		endcase
	end


	/*

	always_comb begin: Datapath
		for (int i = 0; i < 8; i++) begin
			axis_byte[i] = axis_buf_tdata[i*8 +: 8];
		end

		M_AXIS_TDATA_OUT  = axis_buf_tdata;
		M_AXIS_TKEEP_OUT  = axis_buf_tkeep;
		M_AXIS_TVALID_OUT = axis_buf_tvalid;
		M_AXIS_TLAST_OUT  = axis_buf_tlast;
		M_AXIS_TUSER_OUT  = axis_buf_tuser;
	end

	always_ff @(posedge CLK_300M) begin: Extract_Info
		if (RESET) begin
			in_frame <= 1'b0;
			hdr_byte_idx <= '0;
			HDR_OUT <= '0;
			HDR_OUT_VALID<= 1'b0;
		end else begin
			HDR_OUT_VALID <= 1'b0;

			if (axis_buf_xfer) begin

				// Start of frame
				if (!in_frame) begin
					in_frame <= 1'b1;
					hdr_byte_idx <= '0;
					HDR_OUT <= '0;
				end

				// Header capture only until 14 bytes
				if (hdr_byte_idx < 14) begin
					int unsigned idx;
					idx = hdr_byte_idx;

					for (int i=0; i<8; i++) begin
						if (axis_buf_tkeep[i] && (idx < 14)) begin
							unique case (idx)
								0:  HDR_OUT.eth_dst_mac[47:40] <= axis_byte[i];
								1:  HDR_OUT.eth_dst_mac[39:32] <= axis_byte[i];
								2:  HDR_OUT.eth_dst_mac[31:24] <= axis_byte[i];
								3:  HDR_OUT.eth_dst_mac[23:16] <= axis_byte[i];
								4:  HDR_OUT.eth_dst_mac[15:8]  <= axis_byte[i];
								5:  HDR_OUT.eth_dst_mac[7:0]   <= axis_byte[i];
								6:  HDR_OUT.eth_src_mac[47:40] <= axis_byte[i];
								7:  HDR_OUT.eth_src_mac[39:32] <= axis_byte[i];
								8:  HDR_OUT.eth_src_mac[31:24] <= axis_byte[i];
								9:  HDR_OUT.eth_src_mac[23:16] <= axis_byte[i];
								10: HDR_OUT.eth_src_mac[15:8]  <= axis_byte[i];
								11: HDR_OUT.eth_src_mac[7:0]   <= axis_byte[i];
								12: HDR_OUT.eth_type[15:8]     <= axis_byte[i];
								13: begin
									HDR_OUT.eth_type[7:0] <= axis_byte[i];
									HDR_OUT_VALID         <= 1'b1;
								end
								default: ;
							endcase
							idx++;
						end
					end

					hdr_byte_idx <= idx[4:0];
				end

				// End of frame
				if (axis_buf_tlast) begin
					in_frame <= 1'b0;
				end
			end
		end
	end
	*/

endmodule


