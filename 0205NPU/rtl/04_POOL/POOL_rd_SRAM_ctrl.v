`include "TOP_hardware_defines.vh"

module POOL_rd_SRAM_ctrl
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

    output                  o_rd_en    ,
    output [`log2_ADDR -1:0]o_rd_addr  ,

    output                  o_win_first,
    output                  o_win_last ,
    output [`log2_ADDR -1:0]o_wr_addr
);

wire                    running_r;
wire [`log2_CH-1:0]     ch_cnt_r;
wire [`log2_H -1:0]     oh_cnt_r;
wire [`log2_W -1:0]     ow_cnt_r;
wire [`log2_K -1:0]     ky_cnt_r;
wire [`log2_K -1:0]     kx_cnt_r;

wire                    win_first_d1_r;
wire                    win_last_d1_r;
wire                    last_window_d1_r;
wire [`log2_ADDR-1:0]   addr_out_d1_r;

wire signed [31:0]      ih_base_r;
wire signed [31:0]      iw_base_r;
wire signed [31:0]      ih_base_mul_win_r;
wire signed [31:0]      ky_mul_win_r;
wire [`log2_ADDR-1:0]   ch_base_in_r;
wire [`log2_ADDR-1:0]   addr_out_cur_r;

wire [31:0] win_u32 = {{(32-`log2_W){1'b0}}, i_cfg_Win};
wire [31:0] sx_u32  = {{(32-`log2_S){1'b0}}, i_cfg_Sx};
wire [31:0] sy_u32  = {{(32-`log2_S){1'b0}}, i_cfg_Sy};
wire [31:0] py_u32  = {{(32-`log2_P){1'b0}}, i_cfg_Py};
wire [31:0] px_u32  = {{(32-`log2_P){1'b0}}, i_cfg_Px};

// Constant terms used by the incremental address calculator.
wire [31:0] sy_win_u32 = sy_u32 * win_u32;
wire [31:0] py_win_u32 = py_u32 * win_u32;
wire [`log2_ADDR-1:0] hin_win_uaddr = i_cfg_Hin * i_cfg_Win;
wire [`log2_ADDR-1:0] out_base_uaddr = hin_win_uaddr * i_cfg_CHin;

wire running_safe = (running_r === 1'b1);
wire start_safe   = (start === 1'b1);

wire win_first = running_safe &&
                 (kx_cnt_r === {`log2_K{1'b0}}) &&
                 (ky_cnt_r === {`log2_K{1'b0}});
wire win_last  = running_safe &&
                 (kx_cnt_r === (i_cfg_Kx-1'b1)) &&
                 (ky_cnt_r === (i_cfg_Ky-1'b1));
wire last_window = (ch_cnt_r === (i_cfg_CHin-1'b1)) &&
                   (oh_cnt_r === (i_cfg_Hout-1'b1)) &&
                   (ow_cnt_r === (i_cfg_Wout-1'b1)) &&
                   win_last;

wire start_pulse = start_safe && !running_safe;

wire kx_last = (kx_cnt_r === (i_cfg_Kx-1'b1));
wire ky_last = (ky_cnt_r === (i_cfg_Ky-1'b1));
wire ow_last = (ow_cnt_r === (i_cfg_Wout-1'b1));
wire oh_last = (oh_cnt_r === (i_cfg_Hout-1'b1));
wire ch_last = (ch_cnt_r === (i_cfg_CHin-1'b1));

wire signed [31:0] ih = ih_base_r + $signed({1'b0,ky_cnt_r});
wire signed [31:0] iw = iw_base_r + $signed({1'b0,kx_cnt_r});

wire in_valid = running_safe &&
                (ih >= 0) && (ih < $signed({1'b0,i_cfg_Hin})) &&
                (iw >= 0) && (iw < $signed({1'b0,i_cfg_Win}));

wire signed [63:0] addr_in_signed =
    $signed({1'b0,ch_base_in_r}) + $signed(ih_base_mul_win_r) + $signed(ky_mul_win_r) + $signed(iw);
wire [`log2_ADDR-1:0] addr_in_calc = addr_in_signed[`log2_ADDR-1:0];
wire [`log2_ADDR-1:0] addr_in = in_valid ? addr_in_calc : {`log2_ADDR{1'b0}};

wire running_next = start_pulse ? 1'b1 :
                    ((last_window_d1_r === 1'b1) ? 1'b0 : running_safe);

wire [`log2_K-1:0] kx_next =
    start_pulse ? {`log2_K{1'b0}} :
    (running_safe ? (kx_last ? {`log2_K{1'b0}} : (kx_cnt_r + 1'b1)) : kx_cnt_r);

wire [`log2_K-1:0] ky_next =
    start_pulse ? {`log2_K{1'b0}} :
    (running_safe ? (kx_last ? (ky_last ? {`log2_K{1'b0}} : (ky_cnt_r + 1'b1)) : ky_cnt_r) : ky_cnt_r);

wire [`log2_W-1:0] ow_next =
    start_pulse ? {`log2_W{1'b0}} :
    (running_safe ? ((kx_last && ky_last) ? (ow_last ? {`log2_W{1'b0}} : (ow_cnt_r + 1'b1)) : ow_cnt_r) : ow_cnt_r);

wire [`log2_H-1:0] oh_next =
    start_pulse ? {`log2_H{1'b0}} :
    (running_safe ? ((kx_last && ky_last && ow_last) ? (oh_last ? {`log2_H{1'b0}} : (oh_cnt_r + 1'b1)) : oh_cnt_r) : oh_cnt_r);

wire [`log2_CH-1:0] ch_next =
    start_pulse ? {`log2_CH{1'b0}} :
    (running_safe ? ((kx_last && ky_last && ow_last && oh_last) ? (ch_last ? {`log2_CH{1'b0}} : (ch_cnt_r + 1'b1)) : ch_cnt_r) : ch_cnt_r);

wire signed [31:0] ih_base_next =
    start_pulse ? -$signed({1'b0,py_u32}) :
    ((running_safe && kx_last && ky_last && ow_last) ?
        (oh_last ? -$signed({1'b0,py_u32}) : (ih_base_r + $signed({1'b0,sy_u32}))) :
        ih_base_r);

wire signed [31:0] iw_base_next =
    start_pulse ? -$signed({1'b0,px_u32}) :
    ((running_safe && kx_last && ky_last) ?
        (ow_last ? -$signed({1'b0,px_u32}) : (iw_base_r + $signed({1'b0,sx_u32}))) :
        iw_base_r);

wire signed [31:0] ky_mul_win_next =
    start_pulse ? 32'sd0 :
    ((running_safe && kx_last) ?
        (ky_last ? 32'sd0 : (ky_mul_win_r + $signed({1'b0,win_u32}))) :
        ky_mul_win_r);

wire signed [31:0] ih_base_mul_win_next =
    start_pulse ? -$signed({1'b0,py_win_u32}) :
    ((running_safe && kx_last && ky_last && ow_last) ?
        (oh_last ? -$signed({1'b0,py_win_u32}) : (ih_base_mul_win_r + $signed({1'b0,sy_win_u32}))) :
        ih_base_mul_win_r);

wire [`log2_ADDR-1:0] ch_base_in_next =
    start_pulse ? {`log2_ADDR{1'b0}} :
    ((running_safe && kx_last && ky_last && ow_last && oh_last) ?
        (ch_last ? {`log2_ADDR{1'b0}} : (ch_base_in_r + hin_win_uaddr)) :
        ch_base_in_r);

wire [`log2_ADDR-1:0] addr_out_cur_next =
    start_pulse ? out_base_uaddr :
    ((running_safe && win_last && !last_window) ? (addr_out_cur_r + 1'b1) : addr_out_cur_r);

wire win_first_d1_next   = start_pulse ? 1'b0 : win_first;
wire win_last_d1_next    = start_pulse ? 1'b0 : win_last;
wire last_window_d1_next = start_pulse ? 1'b0 : last_window;
wire [`log2_ADDR-1:0] addr_out_d1_next = start_pulse ? out_base_uaddr : addr_out_cur_r;

sirv_gnrl_dfflr #(.DW(1)) u_running (
    .lden (1'b1),
    .dnxt (running_next),
    .qout (running_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_K)) u_kx (
    .lden (1'b1),
    .dnxt (kx_next),
    .qout (kx_cnt_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_K)) u_ky (
    .lden (1'b1),
    .dnxt (ky_next),
    .qout (ky_cnt_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_W)) u_ow (
    .lden (1'b1),
    .dnxt (ow_next),
    .qout (ow_cnt_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_H)) u_oh (
    .lden (1'b1),
    .dnxt (oh_next),
    .qout (oh_cnt_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_CH)) u_ch (
    .lden (1'b1),
    .dnxt (ch_next),
    .qout (ch_cnt_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(1)) u_win_first_d1 (
    .lden (1'b1),
    .dnxt (win_first_d1_next),
    .qout (win_first_d1_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(1)) u_win_last_d1 (
    .lden (1'b1),
    .dnxt (win_last_d1_next),
    .qout (win_last_d1_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(1)) u_last_window_d1 (
    .lden (1'b1),
    .dnxt (last_window_d1_next),
    .qout (last_window_d1_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_ADDR)) u_addr_out_d1 (
    .lden (1'b1),
    .dnxt (addr_out_d1_next),
    .qout (addr_out_d1_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(32)) u_ih_base (
    .lden (1'b1),
    .dnxt (ih_base_next),
    .qout (ih_base_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(32)) u_iw_base (
    .lden (1'b1),
    .dnxt (iw_base_next),
    .qout (iw_base_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(32)) u_ky_mul_win (
    .lden (1'b1),
    .dnxt (ky_mul_win_next),
    .qout (ky_mul_win_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(32)) u_ih_base_mul_win (
    .lden (1'b1),
    .dnxt (ih_base_mul_win_next),
    .qout (ih_base_mul_win_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_ADDR)) u_ch_base_in (
    .lden (1'b1),
    .dnxt (ch_base_in_next),
    .qout (ch_base_in_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`log2_ADDR)) u_addr_out_cur (
    .lden (1'b1),
    .dnxt (addr_out_cur_next),
    .qout (addr_out_cur_r),
    .clk  (clk),
    .rst_n(rst_n)
);

assign working     = running_safe;
assign done        = (last_window_d1_r === 1'b1);
assign o_rd_en     = (in_valid === 1'b1);
assign o_rd_addr   = addr_in;
assign o_win_first = (win_first_d1_r === 1'b1);
assign o_win_last  = (win_last_d1_r === 1'b1);
assign o_wr_addr   = addr_out_d1_r;

endmodule
