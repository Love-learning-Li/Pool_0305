`include "TOP_hardware_defines.vh"

module TOP_wrapper
(
    input            i_PAD_clk    ,
    input            i_PAD_rst_n  ,
								  
    input  [35  -1:0]i_PAD_IN     ,
    output [35  -1:0]o_PAD_OUT    
);

ONCHIP_RESET u_reset
(
    .clk             (       ),
    .i_rst_n         (       ),
    .o_rst_n         (       )
);                           
					         
ONCHIP_CLK u_clk             
(                            
    .clk             (       ),
    .rst_n           (       ),
    .                (       )
);                           
					         
ONCHIP_CFG u_cfg             
(                            
    .clk             (       ),
    .rst_n           (       ),
    .                (       )
);

NPU_top u_npu
(

);

endmodule
