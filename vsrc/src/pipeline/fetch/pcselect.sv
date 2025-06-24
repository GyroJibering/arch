`ifndef __PCSELECT_SV
`define __PCSELECT_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif 

module pcselect 
    import common::*;
    import pipes::*;
(
    input logic         clk,
    input  u64          pcplus4,      // 顺序执行的PC（通常为 current_pc + 4）
    input  u64          jump_target,  // 跳转目标地址
    input  logic        jump_flag,  // 跳转标志（为1表示跳转）
    input  logic        stall,      // 阻塞信号（为1时保持当前PC不变）
    input  u1           csr_jump_en,      // MRET使能信号
    input  u64          csr_pc_nxt,      // CSR PC选择信号
    output u64          pc_selected
);


word_t pc_temp;

always_ff @(posedge clk) begin
    if (stall)
        pc_temp <= pc_temp;
    else if (csr_jump_en)
        pc_temp <= csr_pc_nxt;
    else
        pc_temp <= jump_flag ? jump_target : pcplus4;
end

assign pc_selected = pc_temp;

/* always_ff @(posedge clk) begin
		if (csr_jump_en) begin
			$display("pc: %h", pcplus4-4);
            // $display("csr pc: %h", csr_pc_nxt);
		end
	end */

endmodule

`endif

