`include "TOP_hardware_defines.vh"


module ctrl_cnt_next #(
    parameter DW = 32
)(
    input              start,
    input              en,
    input              last,
    input  [DW-1:0]    init,
    input  [DW-1:0]    step,
    input  [DW-1:0]    cnt,
    output [DW-1:0]    next
);
// ctrl_cnt_next: 通用计数"下一值"组合逻辑模块（无寄存器）
// 行为：
//   start=1              -> next = init        （加载初始值）
//   start=0, en=1, last=1 -> next = init        （回绕）
//   start=0, en=1, last=0 -> next = cnt + step  （步进累加）
//   start=0, en=0        -> next = cnt          （保持）

    assign next = start ? init :
                  (en ? (last ? init : (cnt + step)) : cnt);
endmodule

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

wire signed [`POOL_CALC_DW-1:0]      ih_base_r;
wire signed [`POOL_CALC_DW-1:0]      iw_base_r;
wire signed [`POOL_CALC_DW-1:0]      ih_base_mul_win_r;
wire signed [`POOL_CALC_DW-1:0]      ky_mul_win_r;
wire [`log2_ADDR-1:0]   ch_base_in_r;
wire [`log2_ADDR-1:0]   addr_out_cur_r;

wire [`POOL_CALC_DW-1:0] win_u32 = {{(`POOL_CALC_DW-`log2_W){1'b0}}, i_cfg_Win};
wire [`POOL_CALC_DW-1:0] sx_u32  = {{(`POOL_CALC_DW-`log2_S){1'b0}}, i_cfg_Sx};
wire [`POOL_CALC_DW-1:0] sy_u32  = {{(`POOL_CALC_DW-`log2_S){1'b0}}, i_cfg_Sy};
wire [`POOL_CALC_DW-1:0] py_u32  = {{(`POOL_CALC_DW-`log2_P){1'b0}}, i_cfg_Py};
wire [`POOL_CALC_DW-1:0] px_u32  = {{(`POOL_CALC_DW-`log2_P){1'b0}}, i_cfg_Px};

// Constant terms used by the incremental address calculator.
wire [`POOL_CALC_DW-1:0] sy_win_u32 = sy_u32 * win_u32;
wire [`POOL_CALC_DW-1:0] py_win_u32 = py_u32 * win_u32;
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

wire signed [`POOL_CALC_DW-1:0] ih = ih_base_r + $signed({1'b0,ky_cnt_r});
wire signed [`POOL_CALC_DW-1:0] iw = iw_base_r + $signed({1'b0,kx_cnt_r});

wire in_valid = running_safe &&
                (ih >= 0) && (ih < $signed({1'b0,i_cfg_Hin})) &&
                (iw >= 0) && (iw < $signed({1'b0,i_cfg_Win}));

wire signed [`POOL_CALC_MUL_DW-1:0] addr_in_signed =
    $signed({1'b0,ch_base_in_r}) + $signed(ih_base_mul_win_r) + $signed(ky_mul_win_r) + $signed(iw);
wire [`log2_ADDR-1:0] addr_in_calc = addr_in_signed[`log2_ADDR-1:0];
wire [`log2_ADDR-1:0] addr_in = in_valid ? addr_in_calc : {`log2_ADDR{1'b0}};

wire running_next = start_pulse ? 1'b1 :
                    ((last_window_d1_r === 1'b1) ? 1'b0 : running_safe);

wire [`log2_K-1:0]              kx_next;
wire [`log2_K-1:0]              ky_next;
wire [`log2_W-1:0]              ow_next;
wire [`log2_H-1:0]              oh_next;
wire [`log2_CH-1:0]             ch_next;
wire [`POOL_CALC_DW-1:0]        ih_base_next;
wire [`POOL_CALC_DW-1:0]        iw_base_next;
wire [`POOL_CALC_DW-1:0]        ky_mul_win_next;
wire [`POOL_CALC_DW-1:0]        ih_base_mul_win_next;
wire [`log2_ADDR-1:0]           ch_base_in_next;
wire [`log2_ADDR-1:0]           addr_out_cur_next;

// kx: 最内层卷积核 X 方向计数，每拍步进 1，到 Kx-1 回绕
ctrl_cnt_next #(.DW(`log2_K)) u_kx_next (
    .start (start_pulse),
    .en    (running_safe),
    .last  (kx_last),
    .init  ({`log2_K{1'b0}}),
    .step  ({{(`log2_K-1){1'b0}}, 1'b1}),
    .cnt   (kx_cnt_r),
    .next  (kx_next)
);

// ky: 卷积核 Y 方向计数，kx 完成一轮后步进
ctrl_cnt_next #(.DW(`log2_K)) u_ky_next (
    .start (start_pulse),
    .en    (running_safe & kx_last),
    .last  (ky_last),
    .init  ({`log2_K{1'b0}}),
    .step  ({{(`log2_K-1){1'b0}}, 1'b1}),
    .cnt   (ky_cnt_r),
    .next  (ky_next)
);

// ow: 输出特征图 W 方向计数，kx/ky 均完成一轮后步进
ctrl_cnt_next #(.DW(`log2_W)) u_ow_next (
    .start (start_pulse),
    .en    (running_safe & kx_last & ky_last),
    .last  (ow_last),
    .init  ({`log2_W{1'b0}}),
    .step  ({{(`log2_W-1){1'b0}}, 1'b1}),
    .cnt   (ow_cnt_r),
    .next  (ow_next)
);

// oh: 输出特征图 H 方向计数
ctrl_cnt_next #(.DW(`log2_H)) u_oh_next (
    .start (start_pulse),
    .en    (running_safe & kx_last & ky_last & ow_last),
    .last  (oh_last),
    .init  ({`log2_H{1'b0}}),
    .step  ({{(`log2_H-1){1'b0}}, 1'b1}),
    .cnt   (oh_cnt_r),
    .next  (oh_next)
);

// ch: 输入通道计数
ctrl_cnt_next #(.DW(`log2_CH)) u_ch_next (
    .start (start_pulse),
    .en    (running_safe & kx_last & ky_last & ow_last & oh_last),
    .last  (ch_last),
    .init  ({`log2_CH{1'b0}}),
    .step  ({{(`log2_CH-1){1'b0}}, 1'b1}),
    .cnt   (ch_cnt_r),
    .next  (ch_next)
);

// ih_base: 输入特征图行基地址（有符号），初始为 -Py，每轮 oh 步进 Sy
ctrl_cnt_next #(.DW(`POOL_CALC_DW)) u_ih_base_next (
    .start (start_pulse),
    .en    (running_safe & kx_last & ky_last & ow_last),
    .last  (oh_last),
    .init  (-$signed({1'b0, py_u32})),
    .step  (sy_u32),
    .cnt   (ih_base_r),
    .next  (ih_base_next)
);

// iw_base: 输入特征图列基地址（有符号），初始为 -Px，每轮 ow 步进 Sx
ctrl_cnt_next #(.DW(`POOL_CALC_DW)) u_iw_base_next (
    .start (start_pulse),
    .en    (running_safe & kx_last & ky_last),
    .last  (ow_last),
    .init  (-$signed({1'b0, px_u32})),
    .step  (sx_u32),
    .cnt   (iw_base_r),
    .next  (iw_base_next)
);

// ky_mul_win: ky * Win 的增量累加，每轮 ky 步进 Win
ctrl_cnt_next #(.DW(`POOL_CALC_DW)) u_ky_mul_win_next (
    .start (start_pulse),
    .en    (running_safe & kx_last),
    .last  (ky_last),
    .init  ({`POOL_CALC_DW{1'b0}}),
    .step  (win_u32),
    .cnt   (ky_mul_win_r),
    .next  (ky_mul_win_next)
);

// ih_base_mul_win: ih_base * Win 的增量累加，初始为 -Py*Win，每轮 oh 步进 Sy*Win
ctrl_cnt_next #(.DW(`POOL_CALC_DW)) u_ih_base_mul_win_next (
    .start (start_pulse),
    .en    (running_safe & kx_last & ky_last & ow_last),
    .last  (oh_last),
    .init  (-$signed({1'b0, py_win_u32})),
    .step  (sy_win_u32),
    .cnt   (ih_base_mul_win_r),
    .next  (ih_base_mul_win_next)
);

// ch_base_in: 输入 SRAM 通道基地址，每轮 ch 步进 Hin*Win
ctrl_cnt_next #(.DW(`log2_ADDR)) u_ch_base_in_next (
    .start (start_pulse),
    .en    (running_safe & kx_last & ky_last & ow_last & oh_last),
    .last  (ch_last),
    .init  ({`log2_ADDR{1'b0}}),
    .step  (hin_win_uaddr),
    .cnt   (ch_base_in_r),
    .next  (ch_base_in_next)
);

// addr_out_cur: 输出 SRAM 写地址，每个窗口完成后步进 1
ctrl_cnt_next #(.DW(`log2_ADDR)) u_addr_out_cur_next (
    .start (start_pulse),
    .en    (running_safe & win_last & !last_window),
    .last  (1'b0),
    .init  (out_base_uaddr),
    .step  ({{(`log2_ADDR-1){1'b0}}, 1'b1}),
    .cnt   (addr_out_cur_r),
    .next  (addr_out_cur_next)
);

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

sirv_gnrl_dfflr #(.DW(`POOL_CALC_DW)) u_ih_base (
    .lden (1'b1),
    .dnxt (ih_base_next),
    .qout (ih_base_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`POOL_CALC_DW)) u_iw_base (
    .lden (1'b1),
    .dnxt (iw_base_next),
    .qout (iw_base_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`POOL_CALC_DW)) u_ky_mul_win (
    .lden (1'b1),
    .dnxt (ky_mul_win_next),
    .qout (ky_mul_win_r),
    .clk  (clk),
    .rst_n(rst_n)
);

sirv_gnrl_dfflr #(.DW(`POOL_CALC_DW)) u_ih_base_mul_win (
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
