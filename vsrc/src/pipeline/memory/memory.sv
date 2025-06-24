`ifndef __MEMORY_SV
`define __MEMORY_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module memory 
    import common::*;
    import pipes::*;(
    input  logic          clk,
    input  logic          reset,
    input  execute_data_t dataE,      // 来自执行阶段的数据（包含 ALU 计算出的地址等）
    output memory_data_t  dataM,       // 传递到 MEM/WB 阶段的数据
    output dbus_req_t     dreq,        // 数据总线请求（包含地址、大小、strobe、写数据）
    input  dbus_resp_t    dresp,         // 数据总线响应（返回数据及状态）
    output u1             store_misaligned, // Store 指令是否存在未对齐问题
    output u1             load_misaligned,  // Load 指令是否存在未对齐问题
    output logic          stall_mem,

    output u64            ls_mis_pc     // load and store misaligned pc
    
);

    // 提取当前指令的 opcode
    wire [6:0] opcode = dataE.raw_instr[6:0];

    // 判断是否为 Load 和 Store 指令
    wire is_load;
    wire is_store;

    assign is_load  = (opcode == OP_LOAD);
    assign is_store = (opcode == OP_SD);
    // 数据总线请求有效：Load 或 Store 时均需要访存操作
    assign dreq.valid = (is_load || is_store);// && !store_misaligned;;

    // 使用 ALU 计算出的地址作为访问地址
    assign dreq.addr  = dataE.alu_result;

    logic [2:0] byte_offset = dataE.alu_result[2:0];

    // 根据控制单元的 op 信号，选择访问宽度（Load 和 Store 共用）
    assign dreq.size  = (dataE.ctl.op == LB || dataE.ctl.op == LBU || dataE.ctl.op == SB) ? MSIZE1 :
                        (dataE.ctl.op == LH || dataE.ctl.op == LHU || dataE.ctl.op == SH) ? MSIZE2 :
                        (dataE.ctl.op == LW || dataE.ctl.op == LWU || dataE.ctl.op == SW) ? MSIZE4 :
                        (dataE.ctl.op == LD || dataE.ctl.op == SD)                        ? MSIZE8 : MSIZE4;
                        
    // 对于 Load 指令，strobe 不起作用，全部置0；对于 Store 指令，根据操作类型设置 strobe
    assign dreq.strobe = is_store ? (dataE.ctl.op == SB ? (8'b00000001 << byte_offset) :
                                     dataE.ctl.op == SH ? (8'b00000011 << byte_offset) :
                                     dataE.ctl.op == SW ? (8'b00001111 << byte_offset) :
                                     dataE.ctl.op == SD ? 8'b11111111 : 8'b00000000) : 8'b0;
                                
                                  
    // 对于 Store 指令，dreq.data 为要写入的数据；对于 Load 指令，data字段不使用，置0
    assign dreq.data = is_store ? (dataE.store_data << (byte_offset * 8)) : 64'b0;

    // 阻塞信号
    
    assign stall_mem = (is_load && !dresp.data_ok) || (is_store && !dresp.data_ok);

    // 访存阶段输出数据：如果是 Load 指令且内存响应有效，则从 dresp 中获取数据，
    // 并根据操作类型对数据进行符号扩展或零扩展；否则直接传递 ALU 结果。
    always_comb begin
        if (is_load && dresp.data_ok) begin
            unique case (dataE.ctl.op)
                LB:  dataM.rd = {{56{dresp.data[byte_offset*8+7]}}, dresp.data[byte_offset*8 +: 8]};
                LH:  dataM.rd = {{48{dresp.data[byte_offset*8+15]}}, dresp.data[byte_offset*8 +: 16]};
                LW:  dataM.rd = {{32{dresp.data[byte_offset*8+31]}}, dresp.data[byte_offset*8 +: 32]};
                LD:  dataM.rd = dresp.data;  // 64-bit 直接读取
                LBU: dataM.rd = {{56{1'b0}}, dresp.data[byte_offset*8 +: 8]};
                LHU: dataM.rd = {{48{1'b0}}, dresp.data[byte_offset*8 +: 16]};
                LWU: dataM.rd = {{32{1'b0}}, dresp.data[byte_offset*8 +: 32]};
                default: dataM.rd = 64'b0;
            endcase
        end else begin
            dataM.rd = dataE.alu_result;
        end
    end

    always_comb begin
        if (is_store) begin
            case (dataE.ctl.op)  // 使用执行阶段的操作码，而非 dreq.size
                SH: store_misaligned = (dataE.alu_result[2:0] + 2 > 8);
                SW: store_misaligned = (dataE.alu_result[2:0] + 4 > 8);
                SD: store_misaligned = (dataE.alu_result[2:0] != 0);
                default: store_misaligned = 1'b0;
            endcase
        end else begin
            store_misaligned = 1'b0;
        end
    end
    
    always_comb begin
        load_misaligned = 1'b0;  // 默认无错误
        if (is_load) begin  // 仅在 Load 指令时检测
            case (dataE.ctl.op)
                LH, LHU:   load_misaligned = (dataE.alu_result[2:0] + 2 > 8);
                LW, LWU:   load_misaligned = (dataE.alu_result[2:0] + 4 > 8);
                LD:        load_misaligned = (dataE.alu_result[2:0] != 0);
                default:   load_misaligned = 1'b0;
            endcase
        end
    end


    always_comb begin
        if (is_load && load_misaligned) begin
            ls_mis_pc = dataE.pc;
        end else if (is_store && store_misaligned) begin
            ls_mis_pc = dataE.pc;
        end else begin
            ls_mis_pc = 64'b0;
        end
    end

    /* always_ff @(posedge clk) begin
		if (load_misaligned) begin
			$display("pc: %h", dataE.pc);
		end
	end */
    // 对于 store 指令，不写回寄存器；Load 指令及其他计算指令，写回信号保持原值
    assign dataM.reg_write_en = is_store ? 1'b0 : dataE.reg_write_en;
    
    // 其余信号直接传递
    assign dataM.dst            = dataE.dst;
    assign dataM.pc             = dataE.pc;
    assign dataM.raw_instr      = dataE.raw_instr;
    assign dataM.instr_valid    = dataE.instr_valid;
    assign dataM.jump_flag      = dataE.jump_flag;
    assign dataM.jump_target    = dataE.jump_target;
    assign dataM.mem            = dataE.mem;
    assign dataM.memaddr        = dataE.memaddr;
    assign dataM.ctl            = dataE.ctl;
    assign dataM.csr_wdata = dataE.csr_wdata;
    assign dataM.csr_rdata = dataE.csr_rdata;
endmodule



`endif
