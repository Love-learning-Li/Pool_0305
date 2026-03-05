`include "TOP_hardware_defines.vh"

task run_INT_POOL_software;
    bit signed [`MAX_DAT_DW-1:0] max_val;
    bit signed [`MAX_DAT_DW-1:0] MIN_SIGNED;
    int ih, iw;
    begin
        MIN_SIGNED = - (1 << (`MAX_DAT_DW-1));
        for (int ch=0; ch<`CHout; ch++)
        for (int oh=0; oh<`Hout;  oh++)
        for (int ow=0; ow<`Wout;  ow++) begin
            max_val = MIN_SIGNED;
            for (int ky=0; ky<`Ky; ky++)
            for (int kx=0; kx<`Kx; kx++) begin
                ih = oh*`Sy + ky - `Py;
                iw = ow*`Sx + kx - `Px;
                if (ih<0 || ih>=`Hin || iw<0 || iw>=`Win) begin
                    // ignore out-of-bound
                end else begin
                    if (dat_in[ch][ih][iw] > max_val)
                        max_val = dat_in[ch][ih][iw];
                end
            end
            software_dat_out[ch][oh][ow] = max_val;
        end
    end
endtask


task run_INT_POOL_hardware();
    begin
        start    = 1'b0;
        cfg_Kx = `Kx;
        cfg_Ky = `Ky;
        cfg_Sx = `Sx;
        cfg_Sy = `Sy;
        cfg_Px = `Px;
        cfg_Py = `Py;
        cfg_CHin  = `CHin;
        cfg_Hin   = `Hin;
        cfg_Win   = `Win;
        cfg_CHout = `CHout;
        cfg_Hout  = `Hout;
        cfg_Wout  = `Wout;

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);
        @(posedge clk);
    end
endtask
