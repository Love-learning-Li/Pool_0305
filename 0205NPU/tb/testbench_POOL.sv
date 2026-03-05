`include "TOP_hardware_defines.vh"

/////////////////////////////S0: define software parameters////////////////////////////////
`define Win               8
`define Hin               8
`define CHin              4
				          
`define Ky                3
`define Kx                3
`define Sy                1
`define Sx                1
`define Py                1
`define Px                1
						  
`define half_clk_period   10


/////////////////////////////S1: DONT TOUCH               ////////////////////////////////
`define Wout              ((`Win+2*`Px-`Kx)/`Sx+1)
`define Hout              ((`Hin+2*`Py-`Ky)/`Sy+1)
`define CHout             `CHin

module testbench_POOL;
localparam int DEPTH = (`Win*`Hin*`CHin) + (`Wout*`Hout*`CHout);
localparam int SRAM_ADDR_W = $clog2(DEPTH);

bit clk;
bit rst_n;
always #(`half_clk_period) clk=~clk;

bit flag = 1;
bit signed [`MAX_DAT_DW-1:0] dat_in[`CHin][`Hin][`Win];
bit signed [`MAX_DAT_DW-1:0] software_dat_out[`CHout][`Hout][`Wout];
bit signed [`MAX_DAT_DW-1:0] hardware_dat_out[`CHout][`Hout][`Wout];

// DUT signals
logic                   start;
wire                    working;
wire                    done;
logic [`log2_K-1:0]     cfg_Kx;
logic [`log2_K-1:0]     cfg_Ky;
logic [`log2_S-1:0]     cfg_Sx;
logic [`log2_S-1:0]     cfg_Sy;
logic [`log2_P-1:0]     cfg_Px;
logic [`log2_P-1:0]     cfg_Py;
logic [`log2_CH-1:0]    cfg_CHin;
logic [`log2_H-1:0]     cfg_Hin;
logic [`log2_W-1:0]     cfg_Win;
logic [`log2_CH-1:0]    cfg_CHout;
logic [`log2_H-1:0]     cfg_Hout;
logic [`log2_W-1:0]     cfg_Wout;

`include "tasks_basic.vh"
`include "tasks_POOL.vh"
wire                    o_rd_en;
wire [`log2_ADDR-1:0]   o_rd_addr;
wire                    i_rd_dat_vld;
wire signed [`MAX_DAT_DW-1:0] i_rd_dat_out;
wire                    o_wr_en;
wire [`log2_ADDR-1:0]   o_wr_addr;
wire [`MAX_DAT_DW-1:0]  o_wr_dat;

wire [SRAM_ADDR_W-1:0] rd_addr_sram = o_rd_addr[SRAM_ADDR_W-1:0];
wire [SRAM_ADDR_W-1:0] wr_addr_sram = o_wr_addr[SRAM_ADDR_W-1:0];

initial begin
    clk   = 0;
    rst_n = 0;
    start = 0;
//    $dumpfile("output/pool_tb.vcd");
    $dumpvars(0, testbench_POOL);
    repeat(5) @(posedge clk);
    rst_n = 1;

/////////////////////////////S2: generate test vectors    ////////////////////////////////
    for(int ch=0; ch<`CHin; ch++)
        for(int h=0; h<`Hin; h++)
            for(int w=0; w<`Win; w++)
                dat_in[ch][h][w] = $random();

    for(int ch=0; ch<`CHin; ch++)
        for(int h=0; h<`Hin; h++)
            for(int w=0; w<`Win; w++)
            begin
                int addr;
                addr = ((ch*`Hin + h) * `Win + w);
                u_dat_SRAM.mem[addr] = dat_in[ch][h][w];
            end
			
/////////////////////////////S3: generate golden results  ////////////////////////////////
    run_INT_POOL_software();

/////////////////////////////S4: hardware calculation     ////////////////////////////////
    run_INT_POOL_hardware();

    for(int ch=0; ch<`CHout; ch++)
        for(int oh=0; oh<`Hout; oh++)
            for(int ow=0; ow<`Wout; ow++)
            begin
                int addr;
                int out_base;
                out_base = `Win * `Hin * `CHin;
                addr = out_base + ((ch*`Hout + oh) * `Wout + ow);
                hardware_dat_out[ch][oh][ow] = u_dat_SRAM.mem[addr];
            end
			
/////////////////////////////S5: compare                  ////////////////////////////////
    for(int ch=0; ch<`CHout; ch++)
        for(int oh=0; oh<`Hout; oh++)
            for(int ow=0; ow<`Wout; ow++)
            begin
                if ( hardware_dat_out[ch][oh][ow] != software_dat_out[ch][oh][ow] ) begin
                    flag=0;
                    $display("mismatch! [CH %0d][H %0d][W %0d]=%0d, software=%0d",
                             ch, oh, ow, hardware_dat_out[ch][oh][ow], software_dat_out[ch][oh][ow]);
                end
            end
    if(flag==1)
        $display("\n==================================\n\t  result match      \n==================================");
    else
        $display("\n==================================\n\t  result mismatch   \n==================================");
    
    #10 $finish;
end

initial begin
    #100000000 $finish;
end


/////////////////////////////S6: DUT                  ////////////////////////////////
POOL_TOP u_pool 
(
    .clk             (clk    ),
    .rst_n           (rst_n  ),
    .start           (start ),
    .working         (working),
    .done            (done   ),

    .i_cfg_Kx        (cfg_Kx ),
    .i_cfg_Ky        (cfg_Ky ),
    .i_cfg_Sx        (cfg_Sx ),
    .i_cfg_Sy        (cfg_Sy ),
    .i_cfg_Px        (cfg_Px ),
    .i_cfg_Py        (cfg_Py ),
    .i_cfg_CHin      (cfg_CHin ),
    .i_cfg_Hin       (cfg_Hin ),
    .i_cfg_Win       (cfg_Win ),
    .i_cfg_CHout     (cfg_CHout ),
    .i_cfg_Hout      (cfg_Hout ),
    .i_cfg_Wout      (cfg_Wout ),

    .o_rd_en         (o_rd_en ),
    .o_rd_addr       (o_rd_addr),
    .i_rd_dat_vld    (i_rd_dat_vld),
    .i_rd_dat_out    (i_rd_dat_out),

    .o_wr_en         (o_wr_en ),
    .o_wr_addr       (o_wr_addr),
    .o_wr_dat        (o_wr_dat)
);

DP_SRAM #(
    .DATA_WIDTH(`MAX_DAT_DW),
    .DEPTH     (DEPTH)
) u_dat_SRAM
(
    .wr_clk          (clk       ),
    .wr_rst_n        (rst_n     ),
    .wr_en           (o_wr_en   ),
    .wr_addr         (wr_addr_sram),
    .wr_dat          (o_wr_dat  ),
    
    .rd_clk          (clk       ),
    .rd_rst_n        (rst_n     ),
    .rd_en           (o_rd_en   ),
    .rd_addr         (rd_addr_sram),
    .rd_dat_vld      (i_rd_dat_vld),
    .rd_dat_out      (i_rd_dat_out)
); 

endmodule
