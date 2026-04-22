//================================================================================================
// Copyright (c) 2026 Tomas Andrijasevic

// This source code is provided for viewing and educational purposes only.

// You may not copy, modify, distribute, sublicense, or use this code
// for commercial purposes without explicit permission from the author.
//================================================================================================

//================================================================================================
// Project     : RECAP
// Module      : tc_axis_skid_buffer
// Author      : Tomas Andrijasevic
//
// Description :
//================================================================================================
`timescale 1ns/1ps

`include "test_defines.svh"

module tc_axis_skid_buffer;

   parameter PAYLOAD_LEN = 60;

   import eth_utils_pkg::*;

   tb i_tb();

   // Test frame (60 bytes payload + 4 bytes FCS placeholder = 64 total)
   logic [7:0] test_frame_arp[] = '{
      // Ethernet Header (14 bytes)
      8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,  // Dest MAC (broadcast)
      8'h00, 8'h01, 8'h02, 8'h03, 8'h04, 8'h05,  // Src MAC
      8'h08, 8'h00,                              // EtherType (IPv4)
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

   int in_frames  = 0;
   int out_frames = 0;
   int in_beats   = 0;
   int out_beats  = 0;

   typedef struct {
      logic [63:0] tdata;
      logic [7:0]  tkeep;
      logic        tlast;
      logic        tuser;
   } axis_beat_t;

   axis_beat_t exp_q[$];
   axis_beat_t exp_beat;
   axis_beat_t got_beat;

   // ----------------------------------------------------------------
   // Scoreboard
   //
   // Push every accepted input beat into queue.
   // Pop and compare on every accepted output beat.
   always @(posedge `udp.CLK_300M) begin
      if (`tb.tb_reset) begin
         exp_q.delete();
         in_frames  <= 0;
         out_frames <= 0;
         in_beats   <= 0;
         out_beats  <= 0;
      end else begin

         // Capture expected beat at skid buffer input
         if (`skid_buffer.S_AXIS_TVALID_IN && `skid_buffer.S_AXIS_TREADY_OUT) begin
            exp_beat.tdata = `skid_buffer.S_AXIS_TDATA_IN;
            exp_beat.tkeep = `skid_buffer.S_AXIS_TKEEP_IN;
            exp_beat.tlast = `skid_buffer.S_AXIS_TLAST_IN;
            exp_beat.tuser = `skid_buffer.S_AXIS_TUSER_IN;

            exp_q.push_back(exp_beat);
            in_beats <= in_beats + 1;

            if (`skid_buffer.S_AXIS_TLAST_IN) begin
               in_frames <= in_frames + 1;
            end
         end

         // Compare actual beat at skid buffer output
         if (`skid_buffer.M_AXIS_TVALID_OUT && `skid_buffer.M_AXIS_TREADY_IN) begin
            out_beats <= out_beats + 1;

            if (`skid_buffer.M_AXIS_TLAST_OUT) begin
               out_frames <= out_frames + 1;
            end

            if (exp_q.size() == 0) begin
               $error("[%0t] Output beat seen with empty expected queue", $time);
            end else begin
               got_beat.tdata = `skid_buffer.M_AXIS_TDATA_OUT;
               got_beat.tkeep = `skid_buffer.M_AXIS_TKEEP_OUT;
               got_beat.tlast = `skid_buffer.M_AXIS_TLAST_OUT;
               got_beat.tuser = `skid_buffer.M_AXIS_TUSER_OUT;

               exp_beat = exp_q.pop_front();

               if (got_beat.tdata !== exp_beat.tdata) begin
                  $error("[%0t] TDATA mismatch. exp=%016h got=%016h", $time, exp_beat.tdata, got_beat.tdata);
               end

               if (got_beat.tkeep !== exp_beat.tkeep) begin
                  $error("[%0t] TKEEP mismatch. exp=%02h got=%02h", $time, exp_beat.tkeep, got_beat.tkeep);
               end

               if (got_beat.tlast !== exp_beat.tlast) begin
                  $error("[%0t] TLAST mismatch. exp=%0b got=%0b", $time, exp_beat.tlast, got_beat.tlast);
               end

               if (got_beat.tuser !== exp_beat.tuser) begin
                  $error("[%0t] TUSER mismatch. exp=%0b got=%0b", $time, exp_beat.tuser, got_beat.tuser);
               end
            end
         end
      end
   end

   // ----------------------------------------------------------------
   // Test sequence
   initial begin
      $display("AXIS SKID BUFFER DESIGN TEST (sanity)");
      $display("[%0t] Reset...", $time);
      `tb.tb_reset   = 1;
      `udp.tb_ready  = 1'b1;
      #1000;
      `tb.tb_reset   = 0;
      #500_000;

      // Append correct FCS for what we are actually sending
      eth_utils_pkg::append_fcs_ethernet(test_frame_arp, 60);

      $display("[%0t] Sending ARP test frame...", $time);
      $display("FCS bytes = %02x %02x %02x %02x",
               test_frame_arp[60], test_frame_arp[61], test_frame_arp[62], test_frame_arp[63]);

      repeat (10) begin
         fork
            begin
               `phy.send_ethernet_frame(test_frame_arp, 64);
            end

            begin
               wait (`skid_buffer.M_AXIS_TVALID_OUT == 1'b1);

               // Random backpressure
               repeat (20) begin
                  `udp.tb_ready = $urandom_range(0,1);
                  @(posedge `udp.CLK_300M);
               end

               `udp.tb_ready = 1'b1;
            end
         join
      end

      // Let final beats drain
      repeat (20) @(posedge `udp.CLK_300M);

      if (in_beats != out_beats) begin
         $error("Beat mismatch: in=%0d out=%0d", in_beats, out_beats);
      end

      if (in_frames != out_frames) begin
         $error("Frame mismatch: in=%0d out=%0d", in_frames, out_frames);
      end

      if (exp_q.size() != 0) begin
         $error("Expected queue not empty at end of test. Remaining beats=%0d", exp_q.size());
      end

      $finish;
   end

endmodule
