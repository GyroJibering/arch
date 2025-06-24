`ifndef _WB_REG_SV
`define _WB_REG_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif
module wb_reg 
    import common::*;
    import pipes::*;(
    input logic          clk, reset,
    input writeback_data_t  dataW_new,
    input logic          enable, flush,
    input logic          csr_write_finish,
    output writeback_data_t dataW
);
  always_ff @(posedge clk) begin
        if (reset | flush) begin // flush overrides enable
            dataW <= '0;
        end
        /* else if (dataW_new.ctl.csr && ~csr_write_finish) begin
            dataW <= dataW;
        end */
        else if (enable) begin
            dataW <= dataW_new;
        end
    end

endmodule

`endif 

















