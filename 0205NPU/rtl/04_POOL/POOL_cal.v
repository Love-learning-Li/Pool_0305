`include "TOP_hardware_defines.vh"

module POOL_cal
(
    input                          clk       ,
    input                          rst_n     ,
					   
    input                          start     ,
    output                         working   ,
    output                         done      ,
					   
    input  [`log2_K    -1:0]       i_cfg_Kx   ,
    input  [`log2_K    -1:0]       i_cfg_Ky   ,
    input  [`log2_S    -1:0]       i_cfg_Sx   ,
    input  [`log2_S    -1:0]       i_cfg_Sy   ,
    input  [`log2_P    -1:0]       i_cfg_Px   ,
    input  [`log2_P    -1:0]       i_cfg_Py   ,
    input  [`log2_CH   -1:0]       i_cfg_CHin ,
    input  [`log2_H    -1:0]       i_cfg_Hin  ,
    input  [`log2_W    -1:0]       i_cfg_Win  ,
    input  [`log2_CH   -1:0]       i_cfg_CHout,
    input  [`log2_H    -1:0]       i_cfg_Hout ,
    input  [`log2_W    -1:0]       i_cfg_Wout ,
/////////////////////////////////////////////////////

    input                          i_dat_in_vld ,
    input  signed [`MAX_DAT_DW-1:0]i_dat_in_pkt , 
    input                          i_win_first  ,
    input                          i_win_last   ,

    output                         o_dat_out_vld,
    output signed [`MAX_DAT_DW-1:0]o_dat_out_pkt
);

localparam signed [`MAX_DAT_DW-1:0] MIN_SIGNED = {1'b1, {(`MAX_DAT_DW-1){1'b0}}};
wire signed [`MAX_DAT_DW-1:0] max_val;
wire dat_in_vld_safe = (i_dat_in_vld === 1'b1);
wire win_first_safe  = (i_win_first  === 1'b1);
wire win_last_safe   = (i_win_last   === 1'b1);

wire max_update = dat_in_vld_safe && ($signed(i_dat_in_pkt) > $signed(max_val));
wire max_en = win_first_safe || max_update;
wire signed [`MAX_DAT_DW-1:0] max_next =
    win_first_safe ? (dat_in_vld_safe ? i_dat_in_pkt : MIN_SIGNED) :
    (max_update ? i_dat_in_pkt : max_val);
wire signed [`MAX_DAT_DW-1:0] out_next = win_last_safe ? max_next : max_val;

assign working = 1'b0;
assign done    = 1'b0;

sirv_gnrl_dfflr #(.DW(`MAX_DAT_DW)) u_max_val (
    .lden (max_en),
    .dnxt (max_next),
    .qout (max_val),
    .clk  (clk),
    .rst_n(rst_n)
);

assign o_dat_out_vld = win_last_safe;
assign o_dat_out_pkt = out_next;

endmodule
