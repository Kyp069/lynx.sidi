//-------------------------------------------------------------------------------------------------
module cpu
//-------------------------------------------------------------------------------------------------
(
	input  wire       reset,
	input  wire       clock,
	input  wire       cep,
	input  wire       cen,
	input  wire       mi,
	output wire       mreq,
	output wire       iorq,
	output wire       rfsh,
	output wire       wr,
	output wire       rd,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	output wire[15:0] a
);

T80pa Cpu
(
	.CLK    (clock),
	.CEN_p  (cep  ),
	.CEN_n  (cen  ),
	.RESET_n(reset),
	.BUSRQ_n(1'b1 ),
	.WAIT_n (1'b1 ),
	.BUSAK_n(     ),
	.HALT_n (     ),
	.RFSH_n (rfsh ),
	.MREQ_n (mreq ),
	.IORQ_n (iorq ),
	.NMI_n  (1'b1 ),
	.INT_n  (mi   ),
	.M1_n   (     ),
	.RD_n   (rd   ),
	.WR_n   (wr   ),
	.A      (a    ),
	.DI     (d    ),
	.DO     (q    ),
	.OUT0   (1'b0 ),
	.REG    (     ),
	.DIRSet (1'b0 ),
	.DIR    (212'd0)
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
