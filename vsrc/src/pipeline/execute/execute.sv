`ifndef __EXECUTE_SV
`define __EXECUTE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "src/pipeline/execute/alu.sv"

`else

`endif

module execute 
    import common::*;
    import pipes::*;
(
    input  decode_data_t dataD,         // 来自 decode 阶段的数�?
    output execute_data_t dataE         // 执行阶段输出的数�?
);

    // ALU实例�?
    alu alu_inst (
        .operand1(dataD.srca),
        .operand2(dataD.srcb),
        .alu_op(dataD.ctl.alufunc),
        .result(dataE.alu_result),
        .zero_flag(dataE.zero_flag)
    );

    // 分支条件计算：仅在控制信号中标记�? branch 的指令下才进行比�?
    // 根据不同的分支类型进行比较，生成 branch_taken 信号
    logic branch_taken;
    logic mem;
    word_t memaddr;
    always_comb begin
        if (dataD.ctl.branch) begin
            unique case (dataD.ctl.op)
                BEQ:   branch_taken = (dataD.srca == dataD.srcb);
                BNE:   branch_taken = (dataD.srca != dataD.srcb);
                BLT:   branch_taken = ($signed(dataD.srca) < $signed(dataD.srcb));
                BGE:   branch_taken = ($signed(dataD.srca) >= $signed(dataD.srcb));
                BLTU:  branch_taken = (dataD.srca < dataD.srcb);
                BGEU:  branch_taken = (dataD.srca >= dataD.srcb);
                default: branch_taken = 1'b0;
            endcase
        end else begin
            branch_taken = 1'b0;
        end
    end

    // 计算跳转目标地址�?
    // 如果是跳转（jump）指令，则目标地�?�? dataD.jump_target（由 decode 计算）提�?
    // 如果是分支指令且分支条件满足，则目标地址同样�? dataD.jump_target提供；否则，使用 ALU 结果（顺序执行）
    
    assign dataE.jump_target = (dataD.ctl.jump || (dataD.ctl.branch && branch_taken)) 
                 ? dataD.jump_target 
                 : '0;


    assign dataE.jump_flag = dataD.ctl.jump || (dataD.ctl.branch && branch_taken);

    // 将执行阶段数据打包传递到 dataE
    assign dataE.srca           = dataD.srca;
    assign dataE.srcb           = dataD.srcb;
    assign dataE.ctl            = dataD.ctl;
    assign dataE.reg_write_en   = dataD.ctl.regwrite;
    assign dataE.pc             = dataD.pc;
    assign dataE.raw_instr      = dataD.raw_instr;
    assign dataE.instr_valid    = dataD.instr_valid;
    assign dataE.dst            = dataD.dst;
    assign dataE.store_data     = dataD.store_data;
    assign dataE.mem            = mem;
    assign dataE.memaddr        = memaddr;
    
    

    always_comb begin
        // 默认�?
        mem = 1'b0;
        memaddr = 64'b0;

        unique case (dataD.ctl.op)
            LB, LH, LW, LBU, LHU, LWU, LD,
            SB, SH, SW, SD: begin
                mem = 1'b1;
                memaddr = dataD.srca + dataD.srcb; // 计算访存地址
            end
            default: begin
                mem = 1'b0;
                memaddr = 64'b0;
            end
        endcase
    end

    //----------------------------------------------------------------------  
    // CSR 写使�? / 地址 / 写数�?
    //----------------------------------------------------------------------  
    // decode 阶段已经�? ctl.csr, csr_we, csr_addr 打包好了
    assign dataE.csr       = dataD.ctl.csr;
    assign dataE.csr_we    = dataD.ctl.csr && dataD.ctl.csr_we;
    assign dataE.csr_addr  = dataD.ctl.csr_addr;
    // assign dataE.csr_wdata = dataD.srca;
    assign dataE.csr_wdata = dataD.csr_wdata;
    assign dataE.csr_rdata = dataD.csr_rdata;

endmodule

`endif
