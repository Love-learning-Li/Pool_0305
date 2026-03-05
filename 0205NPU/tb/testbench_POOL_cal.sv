`timescale 1ns/1ps
`include "TOP_hardware_defines.vh"

module testbench_POOL_cal;

localparam int HALF_CLK_PERIOD = 10;
localparam int RANDOM_CASES = 20;
localparam int RANDOM_WIN_MAX_LEN = 12;
localparam signed [`MAX_DAT_DW-1:0] MIN_SIGNED = {1'b1, {(`MAX_DAT_DW-1){1'b0}}};

bit clk;
bit rst_n;

logic start;
wire  working;
wire  done;

logic [`log2_K-1:0]  i_cfg_Kx;
logic [`log2_K-1:0]  i_cfg_Ky;
logic [`log2_S-1:0]  i_cfg_Sx;
logic [`log2_S-1:0]  i_cfg_Sy;
logic [`log2_P-1:0]  i_cfg_Px;
logic [`log2_P-1:0]  i_cfg_Py;
logic [`log2_CH-1:0] i_cfg_CHin;
logic [`log2_H-1:0]  i_cfg_Hin;
logic [`log2_W-1:0]  i_cfg_Win;
logic [`log2_CH-1:0] i_cfg_CHout;
logic [`log2_H-1:0]  i_cfg_Hout;
logic [`log2_W-1:0]  i_cfg_Wout;

logic                           i_dat_in_vld;
logic signed [`MAX_DAT_DW-1:0]  i_dat_in_pkt;
logic                           i_win_first;
logic                           i_win_last;

wire                            o_dat_out_vld;
wire signed [`MAX_DAT_DW-1:0]   o_dat_out_pkt;

int total_cnt;
int pass_cnt;
int fail_cnt;

always #(HALF_CLK_PERIOD) clk = ~clk;

POOL_cal dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .start        (start),
    .working      (working),
    .done         (done),
    .i_cfg_Kx     (i_cfg_Kx),
    .i_cfg_Ky     (i_cfg_Ky),
    .i_cfg_Sx     (i_cfg_Sx),
    .i_cfg_Sy     (i_cfg_Sy),
    .i_cfg_Px     (i_cfg_Px),
    .i_cfg_Py     (i_cfg_Py),
    .i_cfg_CHin   (i_cfg_CHin),
    .i_cfg_Hin    (i_cfg_Hin),
    .i_cfg_Win    (i_cfg_Win),
    .i_cfg_CHout  (i_cfg_CHout),
    .i_cfg_Hout   (i_cfg_Hout),
    .i_cfg_Wout   (i_cfg_Wout),
    .i_dat_in_vld (i_dat_in_vld),
    .i_dat_in_pkt (i_dat_in_pkt),
    .i_win_first  (i_win_first),
    .i_win_last   (i_win_last),
    .o_dat_out_vld(o_dat_out_vld),
    .o_dat_out_pkt(o_dat_out_pkt)
);

task automatic drive_beat(
    input logic                          vld,
    input logic signed [`MAX_DAT_DW-1:0] dat,
    input logic                          first,
    input logic                          last
);
begin
    i_dat_in_vld = vld;
    i_dat_in_pkt = dat;
    i_win_first  = first;
    i_win_last   = last;
    @(posedge clk);
end
endtask

task automatic check_last(
    input string tc_name,
    input logic signed [`MAX_DAT_DW-1:0] exp
);
begin
    total_cnt++;
    if ((o_dat_out_vld === 1'b1) && ($signed(o_dat_out_pkt) === $signed(exp))) begin
        pass_cnt++;
        $display("[PASS] %s exp=%0d got=%0d", tc_name, exp, o_dat_out_pkt);
    end else begin
        fail_cnt++;
        $display("[FAIL] %s exp=%0d got_vld=%b got=%0d", tc_name, exp, o_dat_out_vld, o_dat_out_pkt);
    end
end
endtask

task automatic run_directed_cases;
begin
    // W0: single-point window
    drive_beat(1'b1, 16'sd5,      1'b1, 1'b1);
    check_last("W0_single_point", 16'sd5);

    // W1: normal positive numbers
    drive_beat(1'b1, 16'sd3,      1'b1, 1'b0);
    drive_beat(1'b1, 16'sd12,     1'b0, 1'b0);
    drive_beat(1'b1, 16'sd7,      1'b0, 1'b1);
    check_last("W1_positive", 16'sd12);

    // W2: all negative numbers
    drive_beat(1'b1, -16'sd8,     1'b1, 1'b0);
    drive_beat(1'b1, -16'sd3,     1'b0, 1'b0);
    drive_beat(1'b1, -16'sd20,    1'b0, 1'b1);
    check_last("W2_all_negative", -16'sd3);

    // W3: first beat invalid (padding-like behavior)
    drive_beat(1'b0, 16'sd0,      1'b1, 1'b0);
    drive_beat(1'b1, -16'sd1,     1'b0, 1'b0);
    drive_beat(1'b1, 16'sd4,      1'b0, 1'b1);
    check_last("W3_first_invalid", 16'sd4);

    // W4: all beats invalid -> MIN_SIGNED
    drive_beat(1'b0, 16'sd0,      1'b1, 1'b0);
    drive_beat(1'b0, 16'sd0,      1'b0, 1'b0);
    drive_beat(1'b0, 16'sd0,      1'b0, 1'b1);
    check_last("W4_all_invalid", MIN_SIGNED);

    // W5: equal values tie
    drive_beat(1'b1, 16'sd9,      1'b1, 1'b0);
    drive_beat(1'b1, 16'sd9,      1'b0, 1'b0);
    drive_beat(1'b1, 16'sd8,      1'b0, 1'b1);
    check_last("W5_equal_tie", 16'sd9);

    // W6: random-like fixed sample
    drive_beat(1'b1, -16'sd100,   1'b1, 1'b0);
    drive_beat(1'b1, 16'sd45,     1'b0, 1'b0);
    drive_beat(1'b1, 16'sd23,     1'b0, 1'b0);
    drive_beat(1'b1, 16'sd102,    1'b0, 1'b0);
    drive_beat(1'b1, -16'sd7,     1'b0, 1'b1);
    check_last("W6_mixed_fixed", 16'sd102);

    // W7: X-state vld should be ignored due to (vld === 1'b1)
    drive_beat(1'b1, 16'sd2,      1'b1, 1'b0);
    drive_beat(1'bx, 16'sd30000,  1'b0, 1'b0);
    drive_beat(1'b1, 16'sd7,      1'b0, 1'b1);
    check_last("W7_x_vld_ignored", 16'sd7);
end
endtask

task automatic run_random_cases;
    int case_id;
    int win_len;
    int beat;
    logic vld;
    logic signed [`MAX_DAT_DW-1:0] dat;
    logic signed [`MAX_DAT_DW-1:0] exp_max;
begin
    for (case_id = 0; case_id < RANDOM_CASES; case_id++) begin
        win_len = $urandom_range(1, RANDOM_WIN_MAX_LEN);
        exp_max = MIN_SIGNED;

        for (beat = 0; beat < win_len; beat++) begin
            vld = ($urandom_range(0, 99) < 70);
            dat = $signed($urandom_range(0, (1<<`MAX_DAT_DW)-1));
            if (vld && (dat > exp_max)) begin
                exp_max = dat;
            end

            drive_beat(vld, dat, (beat == 0), (beat == win_len-1));
        end

        check_last($sformatf("RND_%0d_len%0d", case_id, win_len), exp_max);
    end
end
endtask

initial begin
    clk = 0;
    rst_n = 0;

    start      = 1'b0;
    i_cfg_Kx   = '0;
    i_cfg_Ky   = '0;
    i_cfg_Sx   = '0;
    i_cfg_Sy   = '0;
    i_cfg_Px   = '0;
    i_cfg_Py   = '0;
    i_cfg_CHin = '0;
    i_cfg_Hin  = '0;
    i_cfg_Win  = '0;
    i_cfg_CHout= '0;
    i_cfg_Hout = '0;
    i_cfg_Wout = '0;

    i_dat_in_vld = 1'b0;
    i_dat_in_pkt = '0;
    i_win_first  = 1'b0;
    i_win_last   = 1'b0;

    total_cnt = 0;
    pass_cnt  = 0;
    fail_cnt  = 0;

    $dumpvars(0, testbench_POOL_cal);

    repeat(5) @(posedge clk);
    rst_n = 1'b1;

    // Config fields are not used by current POOL_cal implementation, but still drive legal values.
    i_cfg_Kx    = 3;
    i_cfg_Ky    = 3;
    i_cfg_Sx    = 1;
    i_cfg_Sy    = 1;
    i_cfg_Px    = 1;
    i_cfg_Py    = 1;
    i_cfg_CHin  = 1;
    i_cfg_Hin   = 8;
    i_cfg_Win   = 8;
    i_cfg_CHout = 1;
    i_cfg_Hout  = 8;
    i_cfg_Wout  = 8;

    run_directed_cases();
    run_random_cases();

    $display("\n================ POOL_cal SUMMARY ================");
    $display("TOTAL=%0d PASS=%0d FAIL=%0d", total_cnt, pass_cnt, fail_cnt);
    $display("==================================================\n");

    if (fail_cnt == 0) begin
        $display("POOL_cal verification PASSED.");
    end else begin
        $error("POOL_cal verification FAILED.");
    end

    #20;
    $finish;
end

initial begin
    #1000000;
    $error("Timeout reached.");
    $finish;
end

endmodule
