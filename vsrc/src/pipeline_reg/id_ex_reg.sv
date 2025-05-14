`ifndef __ID_EX_REG_SV
`define __ID_EX_REG_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module id_ex_reg 
    import common::*;
    import pipes::*;(
    input logic clk, reset,
    input decode_data_t dataD_new,
    input logic enable, flush,
    output decode_data_t dataD

);
  always_ff @(posedge clk) begin
        if (reset | flush) begin // flush overrides enable
            dataD <= '0;
        end else if (enable) begin
            dataD <= dataD_new;
        end
    end

endmodule

`endif 
