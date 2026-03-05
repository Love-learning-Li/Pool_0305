`include "TOP_hardware_defines.vh"

module POOL_wr_SRAM_ctrl
(
    input                    clk       ,
    input                    rst_n     ,
					   
    input                    start     ,
    output                   working   ,
    output                   done      ,
					   
    input  [`log2_K    -1:0]i_cfg_Kx   ,
    input  [`log2_K    -1:0]i_cfg_Ky   ,
    input  [`log2_S    -1:0]i_cfg_Sx   ,
    input  [`log2_S    -1:0]i_cfg_Sy   ,
    input  [`log2_P    -1:0]i_cfg_Px   ,
    input  [`log2_P    -1:0]i_cfg_Py   ,
    input  [`log2_CH   -1:0]i_cfg_CHin ,
    input  [`log2_H    -1:0]i_cfg_Hin  ,
    input  [`log2_W    -1:0]i_cfg_Win  ,
    input  [`log2_CH   -1:0]i_cfg_CHout,
    input  [`log2_H    -1:0]i_cfg_Hout ,
    input  [`log2_W    -1:0]i_cfg_Wout ,
/////////////////////////////////////////////////////

    input                   i_wr_vld   ,
    input  [`log2_ADDR -1:0]i_wr_addr  ,
    input  signed [`MAX_DAT_DW-1:0]i_wr_dat ,

    output                  o_wr_en     ,
    output [`log2_ADDR -1:0]o_wr_addr   ,
    output [`MAX_DAT_DW-1:0]o_wr_dat    
);

wire running;
wire [`log2_ADDR-1:0] wr_cnt;

wire running_safe = (running === 1'b1);
wire start_safe   = (start === 1'b1);
wire wr_vld_safe  = (i_wr_vld === 1'b1);

wire start_pulse = start_safe && !running_safe;
wire wr_fire = running_safe && wr_vld_safe;
wire [`log2_ADDR-1:0] total_wr_num = i_cfg_CHout * i_cfg_Hout * i_cfg_Wout;
wire [`log2_ADDR-1:0] total_wr_num_m1 =
    (total_wr_num == {`log2_ADDR{1'b0}}) ? {`log2_ADDR{1'b0}} : (total_wr_num - 1'b1);
wire last_wr = wr_fire && (wr_cnt === total_wr_num_m1);
wire running_next = start_pulse ? 1'b1 :
                    (last_wr ? 1'b0 : running_safe);
wire [`log2_ADDR-1:0] wr_cnt_next =
    start_pulse ? {`log2_ADDR{1'b0}} :
    (wr_fire ? (last_wr ? wr_cnt : (wr_cnt + 1'b1)) : wr_cnt);

sirv_gnrl_dfflr #(.DW(1)) u_running (
    .lden (1'b1),
    .dnxt (running_next),
    .qout (running),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_ADDR)) u_wr_cnt (
    .lden (1'b1),
    .dnxt (wr_cnt_next),
    .qout (wr_cnt),
    .clk  (clk),
    .rst_n(rst_n)
);

assign working  = running_safe;
assign done     = (last_wr === 1'b1);
assign o_wr_en  = (wr_fire === 1'b1);
assign o_wr_addr= i_wr_addr;
assign o_wr_dat = i_wr_dat;

endmodule
