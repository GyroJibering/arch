`ifndef __DECODE_SV
`define __DECODE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "include/csr.sv"
`include "src/pipeline/decode/decoder.sv"
`else

`endif

module decode
    import common::*;
    import pipes::*;
    import csr_pkg::*;(
    input fetch_data_t dataF,
    output decode_data_t dataD,
    
    output creg_addr_t ra1, ra2,
    input word_t rd1, rd2,
    
    output u12 csr_addr,
    input word_t csr_rdata
);

    control_t ctl; 
    wire [6:0] opcode   = dataF.raw_instr[6:0];      
    wire [2:0] funct3   = dataF.raw_instr[14:12];     

    word_t imm_i, imm_s, imm_b, imm_u, imm_j, imm_sel;
    assign imm_i = {{52{dataF.raw_instr[31]}}, dataF.raw_instr[31:20]}; // I-type
    assign imm_s = {{52{dataF.raw_instr[31]}}, dataF.raw_instr[31:25], dataF.raw_instr[11:7]}; // S-type
    assign imm_b = {{52{dataF.raw_instr[31]}}, dataF.raw_instr[7], dataF.raw_instr[30:25], dataF.raw_instr[11:8], 1'b0}; // B-type
    assign imm_u = {{32{dataF.raw_instr[31]}}, dataF.raw_instr[31:12], 12'b0}; // U-type
    assign imm_j = {{44{dataF.raw_instr[31]}}, dataF.raw_instr[19:12], dataF.raw_instr[20], dataF.raw_instr[30:21], 1'b0}; // J-type

    assign imm_sel = (opcode == OPC_LUI || opcode == OP_AUIPC) ? imm_u :
                    (opcode == OP_SD)                         ? imm_s :
                    (opcode == OP_BRANCH)                     ? imm_b :
                    (opcode == OP_JAL)                        ? imm_j :
                    (opcode == OP_JALR)                       ? imm_i :
                                                                imm_i; // 默认 I-type

    decoder decoder ( .raw_instr(dataF.raw_instr), .ctl(ctl) ); 

    // 计算源寄存器地址�?
    // LUI、JAL、AUIPC 不需要源寄存器；JALR只需�? rs1；分支（OP_BRANCH）需要两个源寄存器；其余情况使用 rs1 �? rs2
    assign ra1 = ((opcode == OPC_LUI) || (opcode == OP_JAL) || (opcode == OP_AUIPC)) ? '0 : dataF.raw_instr[19:15]; 
    assign ra2 = ((opcode == F7_I_TYPE) || (opcode == F7_IW_TYPE) || (opcode == OP_LOAD) || 
                  (opcode == OPC_LUI) || (opcode == OP_JAL) || (opcode == OP_AUIPC) || (opcode == OP_JALR)) ? '0 
                : ((opcode == OP_BRANCH) ? dataF.raw_instr[24:20] : dataF.raw_instr[24:20]);
    // 对于分支指令（OP_BRANCH）和 R-type Store指令 (OP_SD)，我们需要两个源寄存器，因此 ra2 有效

    // 转发机制：如�? fwd.reg_write_en 有效�? fwd.dst 与对应源寄存器地�?匹配，则采用 fwd.alu_result，否则使用寄存器堆输�?
    wire [4:0] rs1;
    wire [4:0] rs2;
    
    assign rs1 = dataF.raw_instr[19:15];
    assign rs2 = dataF.raw_instr[24:20];
   

    

    // 目的寄存器：rd 字段
    assign dataD.dst = dataF.raw_instr[11:7]; 

    // 源操作数选择�?
    // 对于 I型�?�load、lui、auipc、jal、branch、jalr 指令使用立即�? imm_sel�?
    // 否则使用第二个源寄存器�?�（经过转发后的 fwd_srcb�?
    assign dataD.srca = (opcode == OP_AUIPC || opcode == OP_JAL || opcode == OP_JALR) ? dataF.pc : rd1;
    assign dataD.srcb = ((opcode == F7_I_TYPE)  || 
                        (opcode == F7_IW_TYPE)  || 
                        (opcode == OP_LOAD)     || 
                        (opcode == OPC_LUI)     ||
                        (opcode == OP_SD)       || 
                        (opcode == OP_AUIPC)    || 
                        (opcode == OP_JAL)      || 
                        (opcode == OP_JALR)) ? 
                        ((opcode == OP_JAL)     ||
                        (opcode == OP_JALR)     ? 64'd4 : imm_sel) : rd2;


    // 对于 store 指令，单独保�? store 数据，即 store 指令�? rs2 的�??
    assign dataD.store_data = (opcode == OP_SD) ? rd2 : 64'b0;

    // 计算跳转目标地址�?  
    // - JAL: jump_target = pc + imm_j  
    // - JALR: jump_target = (rs1 + imm_i) & ~1  
    // - Branch: jump_target = pc + imm_b  
    // 对于其他指令，可以默认不跳转（jump_target = 0�?
    wire [63:0] jump_target = (opcode == OP_JAL)  ? (dataF.pc + imm_j) :
                              (opcode == OP_JALR) ? ((rd1 + imm_i) & ~1) :
                              (opcode == OP_BRANCH) ? (dataF.pc + imm_b) : 64'b0;
    assign dataD.jump_target = jump_target;

     // �?查是否是 CSR/系统指令
    wire is_csr             = (opcode == OP_SYSTEM);
    assign csr_addr    = dataF.raw_instr[31:20]; // CSR 地址字段
    wire [4:0] csr_zimm     = dataF.raw_instr[19:15];  // CSRRWI 等用的立即数

    // CSR 译码
    always_comb begin
        dataD.csr_wdata = 64'b0;
        dataD.ctl = ctl;
        dataD.csr_rdata  = 64'b0;    
        if (is_csr) begin
            dataD.ctl.csr = 1'b1;
            dataD.ctl.csr_addr = csr_addr;
            unique case (funct3)
                F3_ECALL:
                unique case (dataF.raw_instr[31:20]) // funct12
                    12'h000: begin dataD.ctl.op = ECALL; dataD.ctl.regwrite = 1'b0; end
                    12'h001: begin dataD.ctl.op = EBREAK; dataD.ctl.regwrite = 1'b0; end
                    12'h302: begin dataD.ctl.op = MRET; dataD.ctl.regwrite = 1'b0; dataD.ctl.csr = 1'b1; dataD.ctl.csr_addr = CSR_MSTATUS; dataD.ctl.csr_we   = 1'b1; end
                    default: begin dataD.ctl.op = UNKNOWN; end
                endcase
                F3_CSRRW:  begin dataD.ctl.op = CSRRW; dataD.csr_wdata = rd1; dataD.csr_rdata = csr_rdata; dataD.ctl.csr_we = 1'b1; dataD.ctl.regwrite = 1'b1; end
                F3_CSRRS:  begin dataD.csr_wdata = rd1; dataD.csr_rdata = csr_rdata; dataD.ctl.csr_we = (rd1 != 0); dataD.ctl.regwrite = 1'b1; end
                F3_CSRRC:  begin dataD.csr_wdata = rd1; dataD.csr_rdata = csr_rdata; dataD.ctl.csr_we = (rd1 != 0); dataD.ctl.regwrite = 1'b1; end
                F3_CSRRWI: begin dataD.csr_wdata = {{59{1'b0}}, csr_zimm}; dataD.csr_rdata = csr_rdata; dataD.ctl.csr_we = 1'b1; dataD.ctl.regwrite = 1'b1; end
                F3_CSRRSI: begin dataD.csr_wdata = csr_rdata | {{59{1'b0}}, csr_zimm}; dataD.csr_rdata = csr_rdata; dataD.ctl.csr_we = (csr_zimm != 0); dataD.ctl.regwrite = 1'b1; end
                F3_CSRRCI: begin dataD.csr_wdata = csr_rdata & ~{{59{1'b0}}, csr_zimm}; dataD.csr_rdata = csr_rdata; dataD.ctl.csr_we = (csr_zimm != 0); dataD.ctl.regwrite = 1'b1; end
                default: begin dataD.csr_wdata = 64'b0; dataD.csr_rdata = 64'b0; dataD.ctl.csr_we = 1'b0; dataD.ctl.regwrite = 1'b0; end
            endcase
        end
    end
  
    assign dataD.pc = dataF.pc; 
    assign dataD.raw_instr = dataF.raw_instr; 
    assign dataD.instr_valid = dataF.instr_valid; 

endmodule

`endif
