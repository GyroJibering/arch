
`ifndef __IF_ID_REG_SV
`define __IF_ID_REG_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif


module if_id_reg 
    import common::*;
    import pipes::*;(
    input logic clk, reset,
    input fetch_data_t dataF_new,
    input logic enable, flush,
    output fetch_data_t dataF

);
  always_ff @(posedge clk) begin
        if (reset | flush) begin // flush overrides enable
            dataF <= '0;
        end else if (enable) begin
            dataF <= dataF_new;
        end
    end

endmodule

`endif 
