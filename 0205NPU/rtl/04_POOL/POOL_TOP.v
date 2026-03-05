`include "TOP_hardware_defines.vh"

module POOL_TOP
(
    input                   clk         ,
    input                   rst_n       ,
									    
    input                   start       ,
    output                  working     ,
    output                  done        ,
									    
    input  [`log2_K    -1:0]i_cfg_Kx    ,
    input  [`log2_K    -1:0]i_cfg_Ky    ,
    input  [`log2_S    -1:0]i_cfg_Sx    ,
    input  [`log2_S    -1:0]i_cfg_Sy    ,
    input  [`log2_P    -1:0]i_cfg_Px    ,
    input  [`log2_P    -1:0]i_cfg_Py    ,
    input  [`log2_CH   -1:0]i_cfg_CHin  ,
    input  [`log2_H    -1:0]i_cfg_Hin   ,
    input  [`log2_W    -1:0]i_cfg_Win   ,
    input  [`log2_CH   -1:0]i_cfg_CHout ,
    input  [`log2_H    -1:0]i_cfg_Hout  ,
    input  [`log2_W    -1:0]i_cfg_Wout  ,
/////////////////////////////////////////////////////

//Rd SRAM
    output                  o_rd_en     ,
    output [`log2_ADDR -1:0]o_rd_addr   ,
    input                   i_rd_dat_vld,
    input  signed [`MAX_DAT_DW-1:0]i_rd_dat_out,
					   
//Wr SRAM               
    output                  o_wr_en     ,
    output [`log2_ADDR -1:0]o_wr_addr   ,
    output [`MAX_DAT_DW-1:0]o_wr_dat    
);

wire win_last_d1;
wire win_first_d1;
wire [`log2_ADDR-1:0] addr_out_d1;
wire signed [`MAX_DAT_DW-1:0] rd_dat = i_rd_dat_out;

wire cal_out_vld;
wire signed [`MAX_DAT_DW-1:0] cal_out_dat;

POOL_rd_SRAM_ctrl u0_rd
(
    .clk            (clk),
    .rst_n          (rst_n),

    .start          (start),
    .working        (working),
    .done           (done),

    .i_cfg_Kx       (i_cfg_Kx),
    .i_cfg_Ky       (i_cfg_Ky),
    .i_cfg_Sx       (i_cfg_Sx),
    .i_cfg_Sy       (i_cfg_Sy),
    .i_cfg_Px       (i_cfg_Px),
    .i_cfg_Py       (i_cfg_Py),
    .i_cfg_CHin     (i_cfg_CHin),
    .i_cfg_Hin      (i_cfg_Hin),
    .i_cfg_Win      (i_cfg_Win),
    .i_cfg_CHout    (i_cfg_CHout),
    .i_cfg_Hout     (i_cfg_Hout),
    .i_cfg_Wout     (i_cfg_Wout),

    .o_rd_en        (o_rd_en),
    .o_rd_addr      (o_rd_addr),
    .o_win_first    (win_first_d1),
    .o_win_last     (win_last_d1),
    .o_wr_addr      (addr_out_d1)
);

POOL_cal u1_cal
(
    .clk            (clk),
    .rst_n          (rst_n),

    .start          (start),
    .working        (),
    .done           (),

    .i_cfg_Kx       (i_cfg_Kx),
    .i_cfg_Ky       (i_cfg_Ky),
    .i_cfg_Sx       (i_cfg_Sx),
    .i_cfg_Sy       (i_cfg_Sy),
    .i_cfg_Px       (i_cfg_Px),
    .i_cfg_Py       (i_cfg_Py),
    .i_cfg_CHin     (i_cfg_CHin),
    .i_cfg_Hin      (i_cfg_Hin),
    .i_cfg_Win      (i_cfg_Win),
    .i_cfg_CHout    (i_cfg_CHout),
    .i_cfg_Hout     (i_cfg_Hout),
    .i_cfg_Wout     (i_cfg_Wout),

    .i_dat_in_vld   (i_rd_dat_vld),
    .i_dat_in_pkt   (rd_dat),
    .i_win_first    (win_first_d1),
    .i_win_last     (win_last_d1),
    .o_dat_out_vld  (cal_out_vld),
    .o_dat_out_pkt  (cal_out_dat)
);

POOL_wr_SRAM_ctrl u2_wr
(
    .clk            (clk),
    .rst_n          (rst_n),

    .start          (start),
    .working        (),
    .done           (),

    .i_cfg_Kx       (i_cfg_Kx),
    .i_cfg_Ky       (i_cfg_Ky),
    .i_cfg_Sx       (i_cfg_Sx),
    .i_cfg_Sy       (i_cfg_Sy),
    .i_cfg_Px       (i_cfg_Px),
    .i_cfg_Py       (i_cfg_Py),
    .i_cfg_CHin     (i_cfg_CHin),
    .i_cfg_Hin      (i_cfg_Hin),
    .i_cfg_Win      (i_cfg_Win),
    .i_cfg_CHout    (i_cfg_CHout),
    .i_cfg_Hout     (i_cfg_Hout),
    .i_cfg_Wout     (i_cfg_Wout),

    .i_wr_vld       (cal_out_vld),
    .i_wr_addr      (addr_out_d1),
    .i_wr_dat       (cal_out_dat),

    .o_wr_en        (o_wr_en),
    .o_wr_addr      (o_wr_addr),
    .o_wr_dat       (o_wr_dat)
);

endmodule
