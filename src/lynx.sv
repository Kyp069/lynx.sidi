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

localparam CONF_STR = {
	"Lynx;;",
	"T0,Reset;",
	"O1,Cas,Off,On;",
	"V,v1.0.",`BUILD_DATE
};

//-------------------------------------------------------------------------------------------------

clock Clock
(
	.inclk0 (clock27),
	.c0     (clock  ), // 48 MHz
	.locked (locked )
);

reg[5:0] ce = 1'd0;
always @(negedge clock) ce <= ce+1'd1;

wire ce12p = ~ce[0] &  ce[1];
wire ce600p = ~ce[0] & ~ce[1] &  ce[2];
wire ce075p = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3] & ~ce[4] &  ce[5];

reg[3:0] ce4= 1'd0;
always @(negedge clock) if(ce400p) ce4 <= 1'd0; else ce4 <= ce4+1'd1;

wire ce400p = ce4[0] &  ce4[1]          &  ce4[3];
wire ce400n = ce4[0] & ~ce4[1] & ce4[2] & ~ce4[3];

//-------------------------------------------------------------------------------------------------

wire reset = keybRr&ready;
wire mi = ~cursor;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.reset  (reset  ),
	.clock  (clock  ),
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

wire[ 7:0] romDo;
wire[romAW-1:0] romA;

rom #(.AW(romAW), .FN(romFN)) Rom
(
	.clock  (clock  ),
	.ce     (ce400p ),
	.q      (romDo  ),
	.a      (romA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] vrbDo1;
wire[13:0] vrbA1;
wire[ 7:0] vrbDi2;
wire[ 7:0] vrbDo2;
wire[13:0] vrbA2;

dpr Rrb
(
	.clock_a  (clock  ),
	.enable_a (ce12p  ),
	.wren_a   (1'b0   ),
	.data_a   (8'hFF  ),
	.q_a      (vrbDo1 ),
	.address_a(vrbA1  ),
	.clock_b  (clock  ),
	.enable_b (ce400p ),
	.wren_b   (vrbWe2 ),
	.data_b   (vrbDi2 ),
	.q_b      (vrbDo2 ),
	.address_b(vrbA2  )
);

wire[ 7:0] vggDo1;
wire[13:0] vggA1;
wire[ 7:0] vggDi2;
wire[ 7:0] vggDo2;
wire[13:0] vggA2;

dpr Rgg
(
	.clock_a  (clock  ),
	.enable_a (ce12p  ),
	.wren_a   (1'b0   ),
	.data_a   (8'hFF  ),
	.q_a      (vggDo1 ),
	.address_a(vggA1  ),
	.clock_b  (clock  ),
	.enable_b (ce400p ),
	.wren_b   (vggWe2 ),
	.data_b   (vggDi2 ),
	.q_b      (vggDo2 ),
	.address_b(vggA2  )
);
	
//-----------------------------------------------------------------------------

wire[15:0] sdrDo;
wire[15:0] sdrDi;
wire[23:0] sdrA;

sdram SDram
(
	.clock   (clock   ),
	.reset   (locked  ),
	.ready   (ready   ),
	.refresh (rfsh    ),
	.write   (sdrWe   ),
	.read    (rd      ),
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

wire io7F = !(!iorq && !wr && a[6:0] == 7'h7F);

reg[7:0] reg7F;
always @(negedge reset, posedge clock) if(!reset) reg7F <= 1'd0; else if(ce400p) if(!io7F) reg7F <= q;

//-------------------------------------------------------------------------------------------------

wire io80 = !(!iorq && !wr && a[7] && !a[6] && !a[2] && !a[1]);

reg[5:1] reg80;
always @(negedge reset, posedge  clock) if(!reset) reg80 <= 1'd0; else if(ce400p) if(!io80) reg80 <= q[5:1];

//-------------------------------------------------------------------------------------------------

wire io84 = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && !a[1]);

reg[5:0] reg84;
always @(negedge reset, posedge clock) if(!reset) reg84 <= 1'd0; else if(ce400p) if(!io84) reg84 <= q[5:0];

//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && a[1]);
wire crtcRs = a[0];
wire crtcRw = wr;

wire[ 7:0] crtcDi = q;

wire[13:0] crtcMa;
wire[ 4:0] crtcRa;

UM6845R Crtc
(
	.TYPE   (1'b1   ),
	.CLOCK  (clock  ),
	.CLKEN  (ce075p ),
	.nRESET (reset  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (crtcDi ),
	.DO     (       ),
	.VSYNC  (vSync  ),
	.HSYNC  (hSync  ),
	.DE     (crtcDe ),
	.FIELD  (       ),
	.CURSOR (cursor ),
	.MA     (crtcMa ),
	.RA     (crtcRa )
);

//-------------------------------------------------------------------------------------------------

wire altg = reg80[4];

wire[ 7:0] vduDi;
wire[ 1:0] vduB;
wire[17:0] vduRGB;

video Video
(
	.reset  (~hSync ),
	.clock  (clock  ),
	.ce     (ce600p ),
	.de     (crtcDe ),
	.altg   (altg   ),
	.d      (vduDi  ),
	.b      (vduB   ),
	.rgb    (vduRGB )
);

osd #(11'd0, 11'd0, 3'd4, 1'b0) Osd
(
	.clk_sys ( clock  ),
	.ce      ( ce600p ),
	.rotate  ( 2'b00  ),
	.SPI_SCK ( spiCk  ),
	.SPI_DI  ( spiDi  ),
	.SPI_SS3 ( spiS3  ),
	.HSync   (~hSync  ),
	.VSync   (~vSync  ),
	.R_in    ( vduRGB[17:12] ),
	.G_in    ( vduRGB[11: 6] ),
	.B_in    ( vduRGB[ 5: 0] ),
	.R_out   (    rgb[17:12] ),
	.G_out   (    rgb[11: 6] ),
	.B_out   (    rgb[ 5: 0] )
);

assign sync = { 1'b1, ~(hSync^vSync) };

//-------------------------------------------------------------------------------------------------

audio Audio
(
	.reset  (reset  ),
	.clock  (clock  ),
	.ear    (ear    ),
	.dac    (reg84  ),
	.audio  (audio  )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] keyCode;
wire[31:0] status;
wire[10:0] ps2 = { keyStrobe, keyPressed, keyExtended, keyCode };

wire[3:0] keybRow = a[11:8];
wire[7:0] keybDo;

keyboard Keyboard
(
	.clock  (clock  ),
//	.ce     (ce600p ),
	.ps2    (ps2    ),
//	.reset  (keybSr ),
//	.cas    (cas    ),
	.row    (keybRow),
	.q      (keybDo )
);

user_io #(.STRLEN(($size(CONF_STR)>>3))) userIo
( 
	.conf_str    (CONF_STR   ),
	.clk_sys     (clock      ),
	.SPI_CLK     (spiCk      ),
	.SPI_SS_IO   (cfgD0      ),
	.SPI_MISO    (spiDo      ),
	.SPI_MOSI    (spiDi      ),
	.status      (status     ),
	.key_code    (keyCode    ),
	.key_strobe  (keyStrobe  ),
	.key_pressed (keyPressed ),
	.key_extended(keyExtended)
);

wire keybRr = ~status[0];
wire cas = ~status[1];

//-------------------------------------------------------------------------------------------------

assign romA = a[romAW-1:0];

//-------------------------------------------------------------------------------------------------

//reg casd;
//reg cas23;

//always @(posedge clock) if(ce600p)
//begin
//	casd <= cas;
//	if(casd && !cas) cas23 <= ~cas23;
//end

assign vduDi = vduB[1] ? (cas || !reg80[3] ? vggDo1 : 8'h00) : (cas || !reg80[2] ? vrbDo1 : 8'h00);
wire[12:0] vmmA = { crtcMa[10:5], crtcRa[1:0], crtcMa[4:0] };

//-------------------------------------------------------------------------------------------------

assign vrbA1 = { vduB[0], vmmA };
assign vrbWe2 = (!mreq && !wr && reg7F[1] && reg80[5]);
assign vrbDi2 = q;
assign vrbA2 = { a[14], a[12:0] };

assign vggA1 = { vduB[0], vmmA };
assign vggWe2 = (!mreq && !wr && reg7F[2] && reg80[5]);
assign vggDi2 = q;
assign vggA2 = { a[14], a[12:0] };

//-------------------------------------------------------------------------------------------------

assign sdrWe = !(!mreq && !wr && !reg7F[0]);
assign sdrDi = {2{q}};
assign sdrA = { 8'h00, ramAW == 14 ? { a[14], a[12:0] } : a };

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
endmodule
//-------------------------------------------------------------------------------------------------
