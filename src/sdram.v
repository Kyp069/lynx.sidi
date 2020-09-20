//-------------------------------------------------------------------------------------------------
module sdram
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       reset,
	output reg        ready,

	input  wire       refresh,
	input  wire       write,
	input  wire       read,
	input  wire[15:0] portDi,
	output reg [15:0] portDo,
	input  wire[23:0] portA,

	output wire       sdramCk,
	output wire       sdramCe,
	output reg        sdramCs,
	output reg        sdramRas,
	output reg        sdramCas,
	output reg        sdramWe,
	output reg [ 1:0] sdramDqm,
	inout  wire[15:0] sdramD,
	output reg [ 1:0] sdramBa,
	output reg [12:0] sdramA
);
//-------------------------------------------------------------------------------------------------
`include "sdram_cmd.v"
//-------------------------------------------------------------------------------------------------

reg[15:0] sdramDo;

assign sdramCk = clock;
assign sdramCe = 1'b1;
assign sdramD = sdramWe ? 16'bZ : sdramDo;

//-----------------------------------------------------------------------------

reg rd, rd2;
reg wr, wr2;
reg rf, rf2;

always @(negedge clock)
begin
	rd2 <= read;
	rd  <= !read && rd2;

	wr2 <= write;
	wr  <= !write && wr2;

	rf2 <= refresh;
	rf  <= !refresh && rf2;
end

//-----------------------------------------------------------------------------

localparam sINIT = 0;
localparam sIDLE = 1;
localparam sREAD = 2;
localparam sWRITE = 3;
localparam sREFRESH = 4;

reg counting;
reg[4:0] count;

reg[2:0] state, next;

always @(posedge clock)
if(!reset) state <= sINIT;
else
begin
	NOP;												// default state is NOP
	if(counting) count <= count+5'd1; else count <= 5'd0;

	case(state)
	sINIT:
	begin
		counting <= 1'b1;

		case(count)
		5'd 0: ready <= 1'b0;
		5'd 8: PRECHARGE(1'b1);							//  8    PRECHARGE: all, tRP's minimum value is 20ns
		5'd12: REFRESH;									// 11    REFRESH, tRFC's minimum value is 66ns
		5'd20: REFRESH;									// 20    REFRESH, tRFC's minimum value is 66ns
		5'd28: LMR(13'b000_1_00_010_0_000);				// 29    LDM: CL = 2, BT = seq, BL = 1, wait 2T
		5'd31:
		begin
			ready <= 1'b1;
			state <= sIDLE;
		end
		endcase
	end
	sIDLE:
	begin
		counting <= 1'b0;

		if(rd) state <= sREAD; else
		if(wr) state <= sWRITE; else
		if(rf) state <= sREFRESH;
	end
	sREAD:
	begin
		counting <= 1'b1;

		case(count)
		5'd0: ACTIVE(portA[23:22], portA[21:9]);
		5'd2: READ(2'b00, 2'b00, portA[8:0], 1'b1);
		5'd5: portDo <= sdramD;
		5'd7: state <= sIDLE;
		endcase
	end
	sWRITE:
	begin
		counting <= 1'b1;

		case(count)
		5'd0: ACTIVE(portA[23:22], portA[21:9]);
		5'd2: WRITE(2'b00, portDi, 2'b00, portA[8:0], 1'b1);
		5'd7: state <= sIDLE;
		endcase
	end
	sREFRESH:
	begin
		counting <= 1'b1;
		case(count)
		5'd0: REFRESH;
		5'd7: state <= sIDLE;
		endcase
	end
	endcase
end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
