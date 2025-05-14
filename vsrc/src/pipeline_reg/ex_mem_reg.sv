`ifndef __EX_MEM_REG_SV
`define __EX_MEM_REG_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif
module ex_mem_reg 
    import common::*;
    import pipes::*;(
    input logic clk, reset,
    input execute_data_t dataE_new,
    input logic enable, flush,
    output execute_data_t dataE

);
  always_ff @(posedge clk) begin
        if (reset | flush) begin // flush overrides enable
            dataE <= '0;
        end else if (enable) begin
            dataE <= dataE_new;
        end
    end

endmodule

`endif 
