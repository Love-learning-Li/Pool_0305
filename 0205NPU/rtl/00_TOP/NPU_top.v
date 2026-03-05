`include "TOP_hardware_defines.vh"

module NPU_top
(
    input                     clk          ,
    input                     rst_n        ,

    input  [`NPU_IN_DW   -1:0]i_dat_in     ,
    input                     i_dat_in_vld ,
    
    output [`NPU_OUT_DW  -1:0]o_dat_out    ,
    output                    o_dat_out_vld
);

SP_SRAM u_wt_SRAM
(
    .wr_clk          (       ),
    .wr_rst_n        (       ),
    .wr_en           (       ),
    .wr_addr         (       ),
    .wr_dat          (       ),
    
    .rd_clk          (       ),
    .rd_rst_n        (       ),
    .rd_en           (       ),
    .rd_addr         (       ),
    .rd_dat_vld      (       ),
    .rd_dat_out      (       )
);                           
                         
DP_SRAM u_dat_SRAM
(
    .wr_clk          (       ),
    .wr_rst_n        (       ),
    .wr_en           (       ),
    .wr_addr         (       ),
    .wr_dat          (       ),
    
    .rd_clk          (       ),
    .rd_rst_n        (       ),
    .rd_en           (       ),
    .rd_addr         (       ),
    .rd_dat_vld      (       ),
    .rd_dat_out      (       )
);                             

CTRL_TOP u_conv             
(                            
    .clk             (       ),
    .rst_n           (       ),
    .                (       )
);    
                     
CONV_TOP u_conv             
(                            
    .clk             (       ),
    .rst_n           (       ),
    .                (       )
);
             
POOL_TOP u_pool 
(
    .clk             (       ),
    .rst_n           (       ),
    .start           (       ),
    .working         (       ),
    .done            (       ),

    .i_cfg_Kx        (       ),
    .i_cfg_Ky        (       ),
    .i_cfg_Sx        (       ),
    .i_cfg_Sy        (       ),
    .i_cfg_Px        (       ),
    .i_cfg_Py        (       ),
    .i_cfg_CHin      (       ),
    .i_cfg_Hin       (       ),
    .i_cfg_Win       (       ),
    .i_cfg_CHout     (       ),
    .i_cfg_Hout      (       ),
    .i_cfg_Wout      (       ),

    .o_rd_en         (       ),
    .o_rd_addr       (       ),
    .i_rd_dat_vld    (       ),
    .i_rd_dat_out    (       ),

    .o_wr_en         (       ),
    .o_wr_addr       (       ),
    .o_wr_dat        (       )
);


endmodule
