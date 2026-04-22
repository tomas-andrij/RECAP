//====================================================================================================================================
// Project     : RECAP
// Module      : axis_skid_buffer
// Author      : Tomas Andrijasevic
//
// Description : Two-entry AXI-Stream skid buffer used to absorb one cycle of downstream backpressure
//               without inserting a bubble into the data path.
//
//               This module sits between an upstream AXI-Stream source and a downstream AXI-Stream sink.
//               It uses:
//                 1) a main output register
//                 2) a temporary register for one extra "skid" beat
//
//               Normal operation:
//                 - If downstream is ready, input data is forwarded into the output register.
//                 - If downstream stalls while the output register is full, one additional input beat
//                   can be captured in the temporary register.
//                 - Once downstream becomes ready again, the saved temporary beat is moved into the
//                   output register and transmission continues.
//
//               The input ready signal is registered. Its next value is computed from the occupancy of
//               the output/temp registers and the downstream ready signal so the buffer can safely accept
//               data one cycle ahead without overflowing.
//
//               Supported sideband signals:
//                 - TKEEP
//                 - TLAST
//                 - TUSER
//
// Purpose: Improve timing robustness and preserve full throughput across short backpressure events in AXI-Stream pipelines.
//====================================================================================================================================
`timescale 1ns/1ps

module axis_skid_buffer #(
	parameter DATA_WIDTH = 64,
	parameter KEEP_WIDTH = 8,
	parameter USER_WIDTH = 1
)(
	input logic CLK,
	input logic RESET,

	// IN
	input  logic [DATA_WIDTH-1:0] S_AXIS_TDATA_IN,
	input  logic [KEEP_WIDTH-1:0] S_AXIS_TKEEP_IN,
	input  logic 					   S_AXIS_TVALID_IN,
	output logic 					   S_AXIS_TREADY_OUT,
	input  logic 					   S_AXIS_TLAST_IN,
	input  logic [USER_WIDTH-1:0] S_AXIS_TUSER_IN,

	// OUT
	output logic [DATA_WIDTH-1:0] M_AXIS_TDATA_OUT,
	output logic [KEEP_WIDTH-1:0] M_AXIS_TKEEP_OUT,
	output logic 						M_AXIS_TVALID_OUT,
	input  logic 						M_AXIS_TREADY_IN,
	output logic 						M_AXIS_TLAST_OUT,
	output logic [USER_WIDTH-1:0]	M_AXIS_TUSER_OUT
);

	logic [DATA_WIDTH-1:0] m_axis_tdata_reg;
	logic [KEEP_WIDTH-1:0] m_axis_tkeep_reg;
	logic                  m_axis_tvalid_reg;
	logic 					  m_axis_tready_reg;
	logic                  m_axis_tlast_reg;
	logic [USER_WIDTH-1:0] m_axis_tuser_reg;

	logic [DATA_WIDTH-1:0] temp_m_axis_tdata_reg;
	logic [KEEP_WIDTH-1:0] temp_m_axis_tkeep_reg;
	logic                  temp_m_axis_tvalid_reg;
	logic                  temp_m_axis_tlast_reg;
	logic [USER_WIDTH-1:0] temp_m_axis_tuser_reg;

	logic m_axis_tready_next;
	logic m_axis_tvalid_next;
	logic temp_m_axis_tvalid_next;

	logic store_axis_input_to_output; // load current S_AXIS beat into the main output register
	logic store_axis_input_to_temp;   // load current S_AXIS beat into the temp register
	logic store_axis_temp_to_output;  // move the saved temp beat into the main output register

	logic in_xfer;
	logic out_xfer;

	assign in_xfer = S_AXIS_TVALID_IN && S_AXIS_TREADY_OUT;
	assign out_xfer = M_AXIS_TVALID_OUT && M_AXIS_TREADY_IN;

	always_comb begin: Ready_Control
		// Use registered version of downstream ready
		S_AXIS_TREADY_OUT = m_axis_tready_reg || !m_axis_tvalid_reg || !temp_m_axis_tvalid_reg;
		m_axis_tready_next = M_AXIS_TREADY_IN;
	end

	always_comb begin : Xfer_Control
		store_axis_input_to_output = 1'b0;
		store_axis_input_to_temp   = 1'b0;
		store_axis_temp_to_output  = 1'b0;

		m_axis_tvalid_next      = m_axis_tvalid_reg;
		temp_m_axis_tvalid_next = temp_m_axis_tvalid_reg;


		case ({m_axis_tvalid_reg, temp_m_axis_tvalid_reg})

			2'b00: begin                             // State 00 — empty
				if (in_xfer) begin                    // 	If in_xfer happens:
					store_axis_input_to_output = 1'b1; //			load input to output
					m_axis_tvalid_next = 1'b1;			  //			next state = 10
				end
			end

			// State 01 - output empty, temp full
			//	should never happen since temp shoud not be occupied while output is empty

			2'b10: begin                             // State 10 — output full, temp empty
				if (in_xfer && out_xfer) begin        //    If both in_xfer and out_xfer:
					store_axis_input_to_output = 1'b1; // 		   old output leaves
					m_axis_tvalid_next = 1'b1;         // 		   new input replaces output
					temp_m_axis_tvalid_next = 1'b0;    // 		   next state = 10
																  //
				end else if (in_xfer) begin           //	  If in_xfer only:
					store_axis_input_to_temp = 1'b1;   //			input goes to temp
					m_axis_tvalid_next = 1'b1;         //			next state = 11
					temp_m_axis_tvalid_next = 1'b1;    //
																  //
				end else if (out_xfer) begin          //	  If out_xfer only:
					m_axis_tvalid_next = 1'b0;         //			output drains
				end                                   //			next state = 00
			end

			2'b11: begin                             // State 11 — output full, temp full
				if (in_xfer && out_xfer) begin        //    If both in_xfer and out_xfer:
																  //       old output leaves
					store_axis_temp_to_output = 1'b1;  //	     temp promotes to output
					store_axis_input_to_temp  = 1'b1;  //	  	  new input fills temp
					m_axis_tvalid_next = 1'b1;         //    	  next state = 11
					temp_m_axis_tvalid_next = 1'b1;    //
				end else if (out_xfer) begin          //   If out_xfer only:
					store_axis_temp_to_output = 1'b1;  //   	  temp promotes to output
					m_axis_tvalid_next = 1'b1;         //		  next state = 10
					temp_m_axis_tvalid_next = 1'b0;    //
				end                                   //   If in_xfer only:
			end                                      //      this should not happen, because full buffer should not accept input (Ready Control block)

			default: begin
				// invalid state; optional recovery
				m_axis_tvalid_next = 1'b0;
				temp_m_axis_tvalid_next = 1'b0;
			end
		endcase
	end

	always_comb begin: Output
		M_AXIS_TDATA_OUT = m_axis_tdata_reg;
		M_AXIS_TKEEP_OUT = m_axis_tkeep_reg;
		M_AXIS_TVALID_OUT = m_axis_tvalid_reg;
		M_AXIS_TLAST_OUT = m_axis_tlast_reg;
		M_AXIS_TUSER_OUT = m_axis_tuser_reg;
	end

	always_ff @(posedge CLK) begin: Buffer
		if (RESET) begin
			m_axis_tdata_reg <= '0;
			m_axis_tkeep_reg <= '0;
			m_axis_tready_reg <= '0;
			m_axis_tvalid_reg <= '0;
         temp_m_axis_tvalid_reg <= '0;
			m_axis_tlast_reg <= '0;
			m_axis_tuser_reg <= '0;

			temp_m_axis_tdata_reg <= '0;
			temp_m_axis_tkeep_reg <= '0;
			temp_m_axis_tvalid_reg <= '0;
			temp_m_axis_tlast_reg <= '0;
			temp_m_axis_tuser_reg <= '0;
		end else begin
			// Update ready/valid
			m_axis_tready_reg <= m_axis_tready_next;
			m_axis_tvalid_reg <= m_axis_tvalid_next;
			temp_m_axis_tvalid_reg <= temp_m_axis_tvalid_next;

			// Output either raw data or temp data
			if (store_axis_input_to_output) begin
				m_axis_tdata_reg <= S_AXIS_TDATA_IN;
				m_axis_tkeep_reg <= S_AXIS_TKEEP_IN;
				m_axis_tlast_reg <= S_AXIS_TLAST_IN;
				m_axis_tuser_reg <= S_AXIS_TUSER_IN;
			end else if (store_axis_temp_to_output) begin
				m_axis_tdata_reg <= temp_m_axis_tdata_reg;
				m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
				m_axis_tlast_reg <= temp_m_axis_tlast_reg;
				m_axis_tuser_reg <= temp_m_axis_tuser_reg;
			end

			// Store raw data into temp data
			if (store_axis_input_to_temp) begin
				temp_m_axis_tdata_reg <= S_AXIS_TDATA_IN;
				temp_m_axis_tkeep_reg <= S_AXIS_TKEEP_IN;
				temp_m_axis_tlast_reg <= S_AXIS_TLAST_IN;
				temp_m_axis_tuser_reg <= S_AXIS_TUSER_IN;
			end
		end
	end
endmodule
