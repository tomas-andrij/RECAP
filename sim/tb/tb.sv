//================================
// Project : RECAP
// Module  : tb
// Author  : Tomas Andrijasevic
//================================

`timescale 1ns/1ps

module tb();

   logic tb_reset;
   logic tb_sysclk_p;
   logic tb_sysclk_n;

   logic tb_clk_125m;
   logic tb_clk_125m_90;
   logic tb_clk_300m;

   logic       rgmii_rx_clk;
   logic       rgmii_rx_ctl;
   logic [3:0] rgmii_rxd;

   logic       rgmii_tx_clk;
   logic       rgmii_tx_ctl;
   logic [3:0] rgmii_txd;

	recap_top i_recap_top (
   	.sysclk_p        (tb_sysclk_p),
      .sysclk_n        (tb_sysclk_n),

      .sw_reset        (tb_reset),

      .i_rgmii_rx_clk  (rgmii_rx_clk),
      .i_rgmii_rx_ctl  (rgmii_rx_ctl),
      .i_rgmii_rxd     (rgmii_rxd),
      .o_rgmii_tx_clk  (rgmii_tx_clk),
      .o_rgmii_tx_ctl  (rgmii_tx_ctl),
      .o_rgmii_txd     (rgmii_txd),

		.mdio_mdc        (),
		.mdio_mdio_io    (),

		.phy_rst_n       (),

      .clk_125m        (tb_clk_125m),
      .clk_125m_90     (tb_clk_125m_90),
      .clk_300m        (tb_clk_300m)
	);

   phy_bfm i_phy_bfm (
      // FPGA -> PHY (what FPGA TX sends to PHY)
      .bfm_rgmii_rx_clk(rgmii_tx_clk),
      .bfm_rgmii_rx_ctl(rgmii_tx_ctl),
      .bfm_rgmii_rxd(rgmii_txd),
   
      // PHY -> FPGA (what PHY sends to FPGA RX)
      .bfm_rgmii_tx_clk(rgmii_rx_clk),
      .bfm_rgmii_tx_ctl(rgmii_rx_ctl),
      .bfm_rgmii_txd(rgmii_rxd)
   );

	initial begin
		tb_clk_125m = 0;
      forever begin 
         #8; 
         tb_clk_125m = ~tb_clk_125m; // 125MHz
      end
	end

   initial begin
      tb_clk_300m = 0;
      forever begin
         #3.333 
         tb_clk_300m = ~tb_clk_300m; // 300MHz
      end
   end

   initial begin
      tb_clk_125m_90 = 0;
      #2; //Phase shift 90
      forever begin
         #8; 
         tb_clk_125m_90 = ~tb_clk_125m_90; //125MHz 90 phase shift
      end
   end

endmodule 
