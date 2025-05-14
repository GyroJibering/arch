`ifndef __DECODER_SV
`define __DECODER_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "include/csr.sv"
`else

`endif
module decoder 
import common::*; 
import pipes::*;
import csr_pkg::*;(
    input  u32 raw_instr, 
    output  control_t ctl 
); 
    wire [6:0] op           = raw_instr[6:0];    // 提取 opcode 
    wire [2:0] f3           = raw_instr[14:12];  // 提取 funct3 
    wire [6:0] f7           = raw_instr[31:25];  // 提取 funct7 
    wire [5:0] f6           = raw_instr[31:26];
    wire [11:0] csr_addr    = raw_instr[31:20]; // CSR 地址字段
    wire [4:0] csr_zimm     = raw_instr[19:15];  // CSRRWI 等用的立即数

    always_comb begin 
        ctl = '0; 
        unique case (op) 
            F7_I_TYPE: begin 
                unique case (f3) 
                    F3_ADD: begin ctl.op = ADDI; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    F3_XOR: begin ctl.op = XORI; ctl.alufunc = ALU_XOR; ctl.regwrite = 1'b1; end 
                    F3_OR:  begin ctl.op = ORI;  ctl.alufunc = ALU_OR;  ctl.regwrite = 1'b1; end 
                    F3_AND: begin ctl.op = ANDI; ctl.alufunc = ALU_AND; ctl.regwrite = 1'b1; end 
                    F3_SLTI: begin ctl.op = SLTI; ctl.alufunc = ALU_SLT; ctl.regwrite = 1'b1; end
                    F3_SLTIU: begin ctl.op = SLTIU; ctl.alufunc = ALU_SLTU; ctl.regwrite = 1'b1; end
                    F3_SRLI: begin 
                        if (f6 == F6_SRAI) begin ctl.op = SRAI; ctl.alufunc = ALU_SRA; end 
                        else begin ctl.op = SRLI; ctl.alufunc = ALU_SRL; end
                        ctl.regwrite = 1'b1;
                    end
                    F3_SLLI: begin ctl.op = SLLI;  ctl.alufunc = ALU_SLL;  ctl.regwrite = 1'b1; end
                    
                    default: begin ctl.op = UNKNOWN; end 
                endcase 
            end 
            F7_IW_TYPE: begin 
                unique case (f3) 
                    F3_ADD:  begin ctl.op = ADDIW; ctl.alufunc = ALU_ADDW; ctl.regwrite = 1'b1; end 
                    F3_SLLIW:  begin ctl.op = SLLIW;  ctl.alufunc = ALU_SLLW;  ctl.regwrite = 1'b1; end 
                    F3_SRLI: begin 
                        if (f6 == F6_SRAIW) begin ctl.op = SRAIW; ctl.alufunc = ALU_SRAIW; end 
                        else if (f6 == F6_SRLIW) begin ctl.op = SRLIW; ctl.alufunc = ALU_SRLIW; end 
                        ctl.regwrite = 1'b1; 
                    end 
                    default: begin ctl.op = UNKNOWN; end 
                endcase 
            end
            F7_R_TYPE: begin 
                unique case ({f7, f3}) 
                    {F7_ADD, F3_ADD}: begin ctl.op = ADD; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    {F7_SUB, F3_SUB}: begin ctl.op = SUB; ctl.alufunc = ALU_SUB; ctl.regwrite = 1'b1; end 
                    {F7_XOR, F3_XOR}: begin ctl.op = XOR; ctl.alufunc = ALU_XOR; ctl.regwrite = 1'b1; end 
                    {F7_OR,  F3_OR }: begin ctl.op = OR;  ctl.alufunc = ALU_OR;  ctl.regwrite = 1'b1; end 
                    {F7_AND, F3_AND}: begin ctl.op = AND; ctl.alufunc = ALU_AND; ctl.regwrite = 1'b1; end 
                    {F7_SLL, F3_SLL}: begin ctl.op = SLL; ctl.alufunc = ALU_SLL; ctl.regwrite = 1'b1; end
                    {F7_SLT, F3_SLT}: begin ctl.op = SLT; ctl.alufunc = ALU_SLT; ctl.regwrite = 1'b1; end
                    {F7_SLTU, F3_SLTU}: begin ctl.op = SLTU; ctl.alufunc = ALU_SLTU; ctl.regwrite = 1'b1; end
                    {F7_SRL, F3_SRL}: begin ctl.op = SRL; ctl.alufunc = ALU_SRL; ctl.regwrite = 1'b1; end
                    {F7_SRA, F3_SRA}: begin ctl.op = SRA; ctl.alufunc = ALU_SRA; ctl.regwrite = 1'b1; end
                    default: begin ctl.op = UNKNOWN; end 
                endcase 
            end 
            F7_RW_TYPE: begin 
                unique case ({f7, f3}) 
                    {F7_SUBW, F3_SUB}: begin ctl.op = SUBW; ctl.alufunc = ALU_SUBW; ctl.regwrite = 1'b1; end 
                    {F7_ADDW, F3_ADD}: begin ctl.op = ADDW; ctl.alufunc = ALU_ADDW; ctl.regwrite = 1'b1; end 
                    {F7_SLLW, F3_SLLW}: begin ctl.op = SLLW; ctl.alufunc = ALU_SLLW; ctl.regwrite = 1'b1; end
                    {F7_SRLW, F3_SRLW}: begin ctl.op = SRLW; ctl.alufunc = ALU_SRLW; ctl.regwrite = 1'b1; end
                    {F7_SRAW, F3_SRAW}: begin ctl.op = SRAW; ctl.alufunc = ALU_SRAW; ctl.regwrite = 1'b1; end
                    default: begin ctl.op = UNKNOWN; end 
                endcase 
            end 
            OP_BRANCH: begin 
                ctl.branch = 1'b1;
                unique case (f3) 
                    F3_BEQ: begin ctl.op = BEQ; ctl.alufunc = ALU_SUB; end 
                    F3_BNE: begin ctl.op = BNE; ctl.alufunc = ALU_SUB; end 
                    F3_BLT: begin ctl.op = BLT; ctl.alufunc = ALU_SLT; end 
                    F3_BGE: begin ctl.op = BGE; ctl.alufunc = ALU_SLT; end 
                    F3_BLTU: begin ctl.op = BLTU; ctl.alufunc = ALU_SLTU; end 
                    F3_BGEU: begin ctl.op = BGEU; ctl.alufunc = ALU_SLTU; end 
                    default: begin ctl.op = UNKNOWN; end 
                endcase 
            end 
            OP_JAL: begin ctl.op = JAL; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; ctl.jump = 1'b1; end 
            OP_JALR: begin ctl.op = JALR; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; ctl.jump = 1'b1; end 
            OP_AUIPC: begin ctl.op = AUIPC; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
            OP_LOAD: begin 
                unique case (f3) 
                    F3_LB:  begin ctl.op = LB;  ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    F3_LH:  begin ctl.op = LH;  ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    F3_LW:  begin ctl.op = LW;  ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    F3_LD:  begin ctl.op = LD;  ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    F3_LBU: begin ctl.op = LBU; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    F3_LHU: begin ctl.op = LHU; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    F3_LWU: begin ctl.op = LWU; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
                    default: begin ctl.op = UNKNOWN; end 
                endcase 
            end 
            OP_SD: begin 
                unique case (f3) 
                    F3_SB: begin ctl.op = SB; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b0; end 
                    F3_SH: begin ctl.op = SH; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b0; end 
                    F3_SW: begin ctl.op = SW; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b0; end 
                    F3_SD: begin ctl.op = SD; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b0; end 
                    default: begin ctl.op = UNKNOWN; end 
                endcase 
            end
            OPC_LUI: begin ctl.op = LUI; ctl.alufunc = ALU_ADD; ctl.regwrite = 1'b1; end 
            
            default: begin ctl.op = UNKNOWN; end 
        endcase 
    end 
endmodule



`endif
