`ifndef __FETCH_SV
`define __FETCH_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif 

module fetch 
    import common::*;
    import pipes::*;(

    output fetch_data_t dataF,
    output u1 instr_misaligned,
    input u32 raw_instr,
    input u64 pc,
    input logic instr_valid,
    output u64 misaligned_pc
);


    // check if the instruction is aligned
    assign instr_misaligned = (pc[1:0] != 2'b00);  // if pc[1:0] != 0, then misaligned
    assign dataF.raw_instr = raw_instr;
    assign dataF.pc = pc;
    assign dataF.instr_valid = instr_valid;
    always_comb begin
        if (instr_misaligned) begin
            misaligned_pc = pc;
        end else begin
            misaligned_pc = 0;
        end
    end
endmodule



`endif

