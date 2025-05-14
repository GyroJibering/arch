`ifndef __ALU_SV
`define __ALU_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module alu 
    import common::*;
    import pipes::*;
(
    input  word_t    operand1,       // 第一个操作数
    input  word_t    operand2,       // 第二个操作数
    input  alufunc_t alu_op,         // ALU操作控制信号
    output word_t    result,         // ALU的结果
    output u1        zero_flag       // 是否为零标志（用于分支判断）
);

    always_comb begin
        logic [31:0] addw_result = '0;
        logic [31:0] subw_result = '0;
        logic [31:0] temp = '0;
        result = '0; // 默认结果为0
        case (alu_op)
            ALU_ADD:    result = operand1 + operand2;
            ALU_SUB:    result = operand1 - operand2;
            ALU_AND:    result = operand1 & operand2;
            ALU_OR:     result = operand1 | operand2;
            ALU_XOR:    result = operand1 ^ operand2;
            
            ALU_SLL:    result = operand1 << operand2[5:0];
            ALU_SLT:    result = ($signed(operand1) < $signed(operand2)) ? 64'b1 : 64'b0;
            ALU_SLTU:   result = (operand1 < operand2) ? 64'b1 : 64'b0;
            ALU_SRL:    result = operand1 >> operand2[5:0];
            ALU_SRA:    result = $signed(operand1) >>> operand2[5:0];
            
            // W扩展指令：32位运算后符号扩展到64位
            ALU_ADDW: begin
                addw_result = operand1[31:0] + operand2[31:0];
                result = {{32{addw_result[31]}}, addw_result};
            end
            ALU_SUBW: begin
                subw_result = operand1[31:0] - operand2[31:0];
                result = {{32{subw_result[31]}}, subw_result};
            end
            ALU_SLLW: begin
                temp = operand1[31:0] << operand2[4:0]; // 只取低5位作为移位数
                result = {{32{temp[31]}}, temp};
            end
            ALU_SRLW: begin
                temp = operand1[31:0] >> operand2[4:0];
                result = {{32{temp[31]}}, temp};
            end
            ALU_SRAW: begin
                temp = $signed(operand1[31:0]) >>> operand2[4:0];
                result = {{32{temp[31]}}, temp};
            end
            // 对于立即数W扩展指令，其功能与对应加法、移位等类似
            ALU_ADDIW: begin
                temp = operand1[31:0] + operand2[31:0];
                result = {{32{temp[31]}}, temp};
            end
            ALU_SRLIW: begin
                temp = operand1[31:0] >> operand2[4:0];
                result = {{32{temp[31]}}, temp};
            end
            ALU_SRAIW: begin
                temp = $signed(operand1[31:0]) >>> operand2[4:0];
                result = {{32{temp[31]}}, temp};
            end
            default: result = '0;
        endcase
    end

    // 零标志，用于分支判断
    always_comb begin
        zero_flag = (result == 0);
    end

endmodule


`endif
