
module DP_SRAM #
(
    parameter DATA_WIDTH =1024,
    parameter DEPTH      = 512,
    parameter log2_DEPTH = $clog2(DEPTH)
)
(
    //Wr Port
    input                  wr_clk    ,
    input                  wr_rst_n  ,
    input                  wr_en     ,
    input  [log2_DEPTH-1:0]wr_addr   ,
    input  [DATA_WIDTH-1:0]wr_dat    ,
   
    //Rd Port
    input                  rd_clk    ,
    input                  rd_rst_n  ,
    input                  rd_en     ,
    input  [log2_DEPTH-1:0]rd_addr   ,
    output reg             rd_dat_vld,
    output [DATA_WIDTH-1:0]rd_dat_out
);

reg [DATA_WIDTH-1:0]rd_dat_r;
reg [DATA_WIDTH-1:0]mem[DEPTH-1:0];

always @(posedge rd_clk)
if(rd_en)
    rd_dat_r<=mem[rd_addr];

always @(posedge rd_clk or negedge rd_rst_n)
if(~rd_rst_n)
    rd_dat_vld<=1'b0;
else
    rd_dat_vld<=rd_en;

always @(posedge wr_clk)
if(wr_en)
    mem[wr_addr]<=wr_dat;

assign rd_dat_out=rd_dat_r;    


endmodule
