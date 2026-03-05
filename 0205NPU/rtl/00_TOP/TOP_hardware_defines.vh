`define NPU_IN_DW                   32
`define NPU_OUT_DW                  32
`define MAX_DAT_DW                  16
`define log2_MAX_DAT_DW             ($clog2(`MAX_DAT_DW))
`define MAX_WT_DW                   16
`define log2_MAX_WT_DW              ($clog2(`MAX_WT_DW))

`define log2_CH                     20
`define log2_H                      10
`define log2_W                      10
`define log2_P                      4
`define log2_S                      4
`define log2_K                      4
`define log2_ADDR                   (`log2_CH + `log2_H + `log2_W + 2)

///////////////////   ON-CHIP WT BUF  ////////////////////
`define SP_SRAM_NUM                 1
`define log2_TOTAL_SP_SRAM_BITS     (25) //= 32Mb
`define TOTAL_SP_SRAM_BITS          (1<<`log2_TOTAL_SP_SRAM_BITS)
`define SINGLE_SP_SRAM_BITS         (`TOTAL_SP_SRAM_BITS/`SP_SRAM_NUM)  
`define SINGLE_SP_SRAM_WIDTH        (128)
`define SINGLE_SP_SRAM_DEPTH        (`SINGLE_SP_SRAM_BITS/`SINGLE_SP_SRAM_WIDTH)

///////////////////   ON-CHIP DAT BUF  ////////////////////
`define DP_SRAM_NUM                 2
`define log2_TOTAL_DP_SRAM_BITS     (24) //= 16Mb
`define TOTAL_DP_SRAM_BITS          (1<<`log2_TOTAL_DP_SRAM_BITS)
`define SINGLE_DP_SRAM_BITS         (`TOTAL_DP_SRAM_BITS/`DP_SRAM_NUM)  
`define SINGLE_DP_SRAM_WIDTH        (128)
`define SINGLE_DP_SRAM_DEPTH        (`SINGLE_DP_SRAM_BITS/`SINGLE_DP_SRAM_WIDTH)
