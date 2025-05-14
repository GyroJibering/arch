`ifndef __MEM_WB_REG_SV
`define __MEM_WB_REG_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif
module mem_wb_reg 
    import common::*;
    import pipes::*;(
    input logic          clk, reset,
    input memory_data_t  dataM_new,
    input logic          enable, flush,
    output memory_data_t dataM
);
  always_ff @(posedge clk) begin
        if (reset | flush) begin // flush overrides enable
            dataM <= '0;
        end else if (enable) begin
            dataM <= dataM_new;
        end
    end

endmodule

`endif 
