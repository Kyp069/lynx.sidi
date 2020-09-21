//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K implementation for SiDi board by Kyp
//-------------------------------------------------------------------------------------------------
// Z80 chip module implementation by Sorgelig
// https://github.com/sorgelig/ZX_Spectrum-128K_MIST
//-------------------------------------------------------------------------------------------------
// UM6845 CRTC chip module implementation by Sorgelig
// https://github.com/sorgelig/Amstrad_MiST
// Some minor modifications done
//-------------------------------------------------------------------------------------------------
module lynx
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock27,
	output wire       led,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       ear,
	output wire[ 1:0] audio,

	output wire       sdramCk,
	output wire       sdramCe,
	output wire       sdramCs,
	output wire       sdramWe,
	output wire       sdramRas,
	output wire       sdramCas,
	output wire[ 1:0] sdramDqm,
	inout  wire[15:0] sdramD,
	output wire[ 1:0] sdramBa,
	output wire[12:0] sdramA,

	input  wire       cfgD0,
	input  wire       spiCk,
	input  wire       spiS2,
	input  wire       spiS3,
	input  wire       spiDi,
	output wire       spiDo
);
//-------------------------------------------------------------------------------------------------

localparam ramAW = 14; // 14 = Lynx 48K, 16 = Lynx 96K/96Kscorpion
localparam romAW = 14; // 14 = Lynx 48K, 15 = Lynx 96K/96Kscorpion
localparam romFN = "48K-1+2.hex"; // "48K-1+2.hex" : "96K-1+2+3.hex" : "96K-1+2+3s.hex"

//-------------------------------------------------------------------------------------------------

wire clock48;
wire clock24;
wire locked;

clock Clock
(
	.inclk0 (clock27),
	.c0     (clock48),
	.c1     (clock24),
	.locked (locked )
);

reg[4:0] ce = 1'd0;
always @(negedge clock24) ce <= ce+1'd1;

wire ce12p  =  ce[0];
wire ce600p = ~ce[0] &  ce[1];
wire ce075p = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3] &  ce[4];

reg[2:0] ce4= 1'd0;
always @(negedge clock24) if(ce400p) ce4 <= 1'd0; else ce4 <= ce4+1'd1;

wire ce400p =  ce4[0]          &  ce4[2];
wire ce400n = ~ce4[0] & ce4[1] & ~ce4[2];

//-------------------------------------------------------------------------------------------------

wire reset = osdRs&keybRs&ready;
wire mi    = ~cursor;
wire mreq;
wire iorq;
wire rfsh;
wire wr;
wire rd;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.reset  (reset  ),
	.clock  (clock24),
	.cep    (ce400p ),
	.cen    (ce400n ),
	.mi     (mi     ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rfsh   (rfsh   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire io7F = !(!iorq && !wr && a[6:0] == 7'h7F);

reg[7:0] reg7F;
always @(negedge reset, posedge clock24) if(!reset) reg7F <= 1'd0; else if(ce400p) if(!io7F) reg7F <= q;

//-------------------------------------------------------------------------------------------------

wire io80 = !(!iorq && !wr && a[7] && !a[6] && !a[2] && !a[1]);

reg[5:1] reg80;
always @(negedge reset, posedge  clock24) if(!reset) reg80 <= 1'd0; else if(ce400p) if(!io80) reg80 <= q[5:1];

//-------------------------------------------------------------------------------------------------

wire io84 = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && !a[1]);

reg[5:0] reg84;
always @(negedge reset, posedge clock24) if(!reset) reg84 <= 1'd0; else if(ce400p) if(!io84) reg84 <= q[5:0];

//-------------------------------------------------------------------------------------------------

wire[ 7:0] romDo;
wire[romAW-1:0] romA = a[romAW-1:0];

rom #(.AW(romAW), .FN(romFN)) Rom
(
	.clock  (clock24),
	.ce     (ce400p ),
	.q      (romDo  ),
	.a      (romA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] vrbDo1;
wire[13:0] vrbA1;
wire       vrbWe2;
wire[ 7:0] vrbDi2;
wire[ 7:0] vrbDo2;
wire[13:0] vrbA2;

dpr Rrb
(
	.clock_a  (clock24),
	.enable_a (ce12p  ),
	.wren_a   (1'b0   ),
	.data_a   (8'hFF  ),
	.q_a      (vrbDo1 ),
	.address_a(vrbA1  ),
	.clock_b  (clock24),
	.enable_b (ce400p ),
	.wren_b   (vrbWe2 ),
	.data_b   (vrbDi2 ),
	.q_b      (vrbDo2 ),
	.address_b(vrbA2  )
);

wire[ 7:0] vggDo1;
wire[13:0] vggA1;
wire       vggWe2;
wire[ 7:0] vggDi2;
wire[ 7:0] vggDo2;
wire[13:0] vggA2;

dpr Rgg
(
	.clock_a  (clock24),
	.enable_a (ce12p  ),
	.wren_a   (1'b0   ),
	.data_a   (8'hFF  ),
	.q_a      (vggDo1 ),
	.address_a(vggA1  ),
	.clock_b  (clock24),
	.enable_b (ce400p ),
	.wren_b   (vggWe2 ),
	.data_b   (vggDi2 ),
	.q_b      (vggDo2 ),
	.address_b(vggA2  )
);
	
//-----------------------------------------------------------------------------

wire       ready;
wire       sdrWe = !(!mreq && !wr && !reg7F[0]);
wire[15:0] sdrDi = {2{q}};
wire[15:0] sdrDo;
wire[23:0] sdrA = { 8'h00, ramAW == 14 ? { a[14], a[12:0] } : a };

sdram SDram
(
	.clock   (clock48 ),
	.reset   (locked  ),
	.ready   (ready   ),
	.refresh (rfsh    ),
	.read    (rd      ),
	.write   (sdrWe   ),
	.portDi  (sdrDi   ),
	.portDo  (sdrDo   ),
	.portA   (sdrA    ),
	.sdramCk (sdramCk ),
	.sdramCe (sdramCe ),
	.sdramCs (sdramCs ),
	.sdramRas(sdramRas),
	.sdramCas(sdramCas),
	.sdramWe (sdramWe ),
	.sdramDqm(sdramDqm),
	.sdramD  (sdramD  ),
	.sdramBa (sdramBa ),
	.sdramA  (sdramA  )
);

//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && a[1]);
wire crtcRs = a[0];
wire crtcRw = wr;
wire crtcDe;

wire[ 7:0] crtcDi = q;
wire[13:0] crtcMa;
wire[ 4:0] crtcRa;

wire cursor;
wire hSync;
wire vSync;

UM6845R Crtc
(
	.TYPE   (1'b1   ),
	.CLOCK  (clock24),
	.CLKEN  (ce075p ),
	.nRESET (reset  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (crtcDi ),
	.DO     (       ),
	.DE     (crtcDe ),
	.FIELD  (       ),
	.MA     (crtcMa ),
	.RA     (crtcRa ),
	.CURSOR (cursor ),
	.VSYNC  (vSync  ),
	.HSYNC  (hSync  )
);

//-------------------------------------------------------------------------------------------------

wire altg = reg80[4];

wire[ 7:0] vduDi = vduB[1] ? (cas || !reg80[3] ? vggDo1 : 8'h00) : (cas || !reg80[2] ? vrbDo1 : 8'h00);
wire[ 1:0] vduB;
wire[17:0] vduRGB;

video Video
(
	.reset  (~hSync ),
	.clock  (clock24),
	.ce     (ce600p ),
	.de     (crtcDe ),
	.altg   (altg   ),
	.d      (vduDi  ),
	.b      (vduB   ),
	.rgb    (vduRGB )
);

//-------------------------------------------------------------------------------------------------

audio Audio
(
	.reset  (reset  ),
	.clock  (clock24),
	.ear    (ear    ),
	.dac    (reg84  ),
	.audio  (audio  )
);

//-------------------------------------------------------------------------------------------------

wire[3:0] keybRow = a[11:8];
wire[7:0] keybDo;
wire      keybRs;

keyboard Keyboard
(
	.clock  (clock24   ),
	.code   (ps2Code   ),
	.strobe (ps2Strobe ),
	.pressed(ps2Pressed),
	.reset  (keybRs    ),
	.row    (keybRow   ),
	.q      (keybDo    )
);

//-------------------------------------------------------------------------------------------------

assign vrbA1 = { vduB[0], crtcMa[10:5], crtcRa[1:0], crtcMa[4:0] };
assign vrbWe2 = (!mreq && !wr && reg7F[1] && reg80[5]);
assign vrbDi2 = q;
assign vrbA2 = { a[14], a[12:0] };

assign vggA1 = { vduB[0], crtcMa[10:5], crtcRa[1:0], crtcMa[4:0] };
assign vggWe2 = (!mreq && !wr && reg7F[2] && reg80[5]);
assign vggDi2 = q;
assign vggA2 = { a[14], a[12:0] };

//-------------------------------------------------------------------------------------------------

assign d
	= !mreq && !reg7F[4] && a[15:14] == 2'b00 ? romDo
	: !mreq && !reg7F[4] && a[15:13] == 3'b010 ? (romAW == 14 ? 8'hFF : romDo)
	: !mreq && !reg7F[5] ? sdrDo[7:0]
	: !mreq &&  reg7F[6] && !reg80[2] ? vrbDo2
	: !mreq &&  reg7F[6] && !reg80[3] ? vggDo2
	: !iorq &&  a[7:0] == 8'h80 ? { keybDo[7:1], reg80[1] ? ear : keybDo[0] }
	: 8'hFF;

//-------------------------------------------------------------------------------------------------

assign led = ~ear;

//-------------------------------------------------------------------------------------------------

localparam CONF_STR = {
	"Lynx;;",
	"T0,Reset;",
	"O1,Bank 2 CAS enable,Off,On;",
	"O2,Scandoubler,Off,On;",
	"O34,Scanlines,None,25%,50%,75%;",
	"V,v1.0"
};

wire[31:0] status;
wire[ 7:0] ps2Code;
wire       ps2Strobe;
wire       ps2Pressed;

user_io #(.STRLEN(($size(CONF_STR)>>3))) userIo
( 
	.conf_str    (CONF_STR   ),
	.clk_sys     (clock24    ),
	.SPI_CLK     (spiCk      ),
	.SPI_SS_IO   (cfgD0      ),
	.SPI_MISO    (spiDo      ),
	.SPI_MOSI    (spiDi      ),
	.status      (status     ),
	.key_code    (ps2Code    ),
	.key_strobe  (ps2Strobe  ),
	.key_pressed (ps2Pressed ),
	.key_extended(           )
);

mist_video mistVideo
(
	.clk_sys   ( clock24   ),
	.SPI_SCK   ( spiCk     ),
	.SPI_DI    ( spiDi     ),
	.SPI_SS3   ( spiS3     ),
	.scanlines (status[4:3]),
	.ce_divider(1'b0       ),
	.scandoubler_disable(~status[2]),
	.no_csync  (1'b0       ),
	.ypbpr     (1'b0       ),
	.rotate    (2'b00      ),
	.blend     (1'b0       ),
	.R         (vduRGB[17:12]),
	.G         (vduRGB[11: 6]),
	.B         (vduRGB[ 5: 0]),
	.HSync     (~hSync     ),
	.VSync     (~vSync     ),
	.VGA_R     (rgb[17:12] ),
	.VGA_G     (rgb[11: 6] ),
	.VGA_B     (rgb[ 5: 0] ),
	.VGA_VS    (sync[1]    ),
	.VGA_HS    (sync[0]    )
);

//assign rgb = vduRGB;
//assign sync = { 1'b1, ~(hSync^vSync) };

wire osdRs = ~status[0];
wire cas = ~status[1];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
