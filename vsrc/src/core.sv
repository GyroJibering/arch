`ifndef __CORE_SV
`define __CORE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "src/pipeline/regfile/regfile.sv"
`include "src/pipeline/fetch/fetch.sv"
`include "src/pipeline/fetch/pcselect.sv"
`include "src/pipeline/decode/decode.sv"
`include "src/pipeline/execute/execute.sv"
`include "src/pipeline/memory/memory.sv"
`include "src/pipeline/writeback/writeback.sv"
`include "src/pipeline_reg/ex_mem_reg.sv"
`include "src/pipeline_reg/id_ex_reg.sv"
`include "src/pipeline_reg/if_id_reg.sv"
`include "src/pipeline_reg/mem_wb_reg.sv"
`include "src/pipeline/csrfile/csrfile.sv"
`include "src/pipeline/mmu/mmu.sv"
`else

`endif

module core 
	import common::*;
	import pipes::*;
	import csr_pkg::*;(
	input 	logic clk, reset,
	output 	ibus_req_t  ireq,
	input  	ibus_resp_t iresp,
	output 	dbus_req_t  dreq,
	input  	dbus_resp_t dresp,
	input 	logic trint, swint, exint
);
	// stall, pc, flush
	u1 				stallpc;
	u64 			pc, pc_nxt;
	logic 			stall_bj;
	logic 			stall_pipeline;
	logic 			stall_csr;
	logic 			stall_mem;
	logic 			stall_mmu;
	logic 			instr_valid; 		
	logic 			flush;
	u1 				stall_mret;
	u1 				stall_ecall;

	// regs, csr regs, privilege mode
	logic[XLEN-1:0] mstatus, mtvec, mip, mie, mscratch;
	logic[XLEN-1:0] mcause, mtval, mepc, mcycle, mhartid, satp;
	logic [63:0] 	difftest_regs[31:0];
	word_t 			csr_rdata;  		// csrfile read data
	u1        		csr_we;
	u12 			csr_addr_r, csr_addr_w;
	word_t 			csr_pc_nxt;
	u2 				mode;

	u32 			raw_instr;
	dbus_req_t 		tmp_dreq;	// tmp
	dbus_resp_t 	tmp_dresp;
	ibus_resp_t 	tmp_iresp;

	fetch_data_t 		dataF, dataF_nxt;
	creg_addr_t 		ra1, ra2;			// reg_address
	word_t 				rd1, rd2;			// reg_data
	decode_data_t 		dataD, dataD_nxt; 	// decode
	execute_data_t 		dataE, dataE_nxt;
	memory_data_t 		dataM, dataM_nxt;
	writeback_data_t 	dataW;

	assign instr_valid 			= tmp_iresp.data_ok;
	assign flush 				= stall_bj || dataW.ctl.csr || dataW.jump_flag;
	assign stallpc 				= ireq.valid && ~tmp_iresp.data_ok || stall_mem || stall_csr || stall_mmu;
	assign stall_pipeline 		= stall_mem || stall_bj;
	assign stall_csr 			= dataD.ctl.csr || dataE.ctl.csr || dataW.ctl.csr || dataM.ctl.csr;
	assign stall_mret 			= dataW.ctl.op == MRET;
	assign stall_ecall 			= dataW.ctl.op == ECALL;

	assign raw_instr 			= instr_valid ? tmp_iresp.data : '0;  

	// when jump_flag is true, stall_bj = 1，until pc == jump_target
	always_ff @(posedge clk or posedge reset) begin
		if (reset)
			stall_bj <= 1'b0;
		else if (dataW.jump_flag || stall_mret || stall_ecall)
			stall_bj <= 1'b1;
		else if (tmp_iresp.data_ok)
			stall_bj <= 1'b0;
		else
			stall_bj <= stall_bj;
	end
	
	/* always_ff @(posedge clk) begin
		if (pc >= 64'h7ffff0000 ) begin
			$display("op: %decode_op_t", dataD.ctl.op);
		end
	end */

	// PC control
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			pc <= 64'h8000_0000;
		end else if (stallpc) begin
			pc <= pc;  // stall时保持不 ?
		end else if (stall_bj) begin
			pc <= pc_nxt;  // flush时更新到跳转目标
		end else begin
			pc <= pc_nxt;
		end
	end

	mmu u_mmu (
        .clk            (clk),
        .reset          (reset),
        .privilegeMode  (mode),
        .dresp          (dresp),
        .tmp_dreq       (tmp_dreq),
        .dreq           (dreq),
        .tmp_dresp      (tmp_dresp),
        .i_addr         (pc),
		.iresp			(iresp),
        .i_valid        (1'b1),
        .ireq           (ireq),
        .satp           (satp),
		.tmp_iresp		(tmp_iresp),
		.stall_mmu		(stall_mmu),
		.op				(dataD.ctl.op)
    );

	
	fetch fetch (
		.dataF(dataF_nxt),
		.raw_instr(raw_instr),
		.pc(pc),
		.instr_valid(instr_valid)
	);
	
	pcselect pcselect (
		.clk(clk),
		.pcplus4(pc + 4),	
		.jump_target(dataW.jump_target),
		.jump_flag(dataW.jump_flag),
		.csr_jump_en(dataW.ctl.op == MRET || dataW.ctl.op == ECALL),
		.csr_pc_nxt(csr_pc_nxt),
		.stall(stall_pipeline),
		.pc_selected(pc_nxt)	
	);

	if_id_reg fd(
		.clk(clk),
		.reset(reset),
		.enable(~stall_pipeline),
		.flush(flush),
		.dataF(dataF),
		.dataF_new(dataF_nxt)
	);

	decode decode (
		.dataF(dataF),
		.dataD(dataD_nxt),		
		.ra1(ra1), .ra2(ra2),	
		.rd1(rd1), .rd2(rd2),	
		.csr_addr(csr_addr_r),	
		.csr_rdata(csr_rdata)	
	);

	regfile regfile (
		.clk(clk), .reset(reset),
		.ra1(ra1), .ra2(ra2), 	
		.rd1(rd1), .rd2(rd2),	
		.wvalid(dataW.wvalid), 
		.wa(dataW.wa),           
		.wd(dataW.wd),            
		.difftest_regs(difftest_regs)
	);
	

	csrfile csrfile_u (
	.clk      (clk),
	.reset    (reset),
	.csr_addr_r(csr_addr_r),   // decode 阶段 ?
	.csr_rdata (csr_rdata),
	.csr_we   (dataD.ctl.csr_we),   
	.csr_addr_w(dataD.ctl.csr_addr),
	.csr_wdata (dataD.csr_wdata),   
	.op(dataD.ctl.op),
	.cur_pc(dataD.pc),
	.nxt_pc(csr_pc_nxt), // 异常返回地址
	.mode(mode),

	.mstatus  (mstatus),
	.mtvec    (mtvec),
	.mip      (mip),
	.mie      (mie),
	.mscratch (mscratch),
	.mcause   (mcause),
	.mtval    (mtval),
	.mepc     (mepc),
	.mcycle   (mcycle),
	.mhartid  (mhartid),
	.satp     (satp)
	);

	id_ex_reg de(
		.clk(clk),
		.reset(reset),
		.enable(~stall_pipeline),
		.flush(flush),
		.dataD(dataD),
		.dataD_new(dataD_nxt)
	);

	execute execute (
		.dataD(dataD),
		.dataE(dataE_nxt)
	);

	ex_mem_reg em(
		.clk(clk),
		.reset(reset),
		.enable(~stall_pipeline),
		.flush(flush),
		.dataE(dataE),
		.dataE_new(dataE_nxt)
	);
	
	memory memory_inst (
		.clk(clk),
		.reset(reset),
		.dataE(dataE),
		.dataM(dataM_nxt),
		.dreq(tmp_dreq),
		.dresp(tmp_dresp),
		// .dreq(dreq),
		// .dresp(dresp),
		.stall_mem(stall_mem)
	);

	mem_wb_reg mw(
		.clk(clk),
		.reset(reset),
		.enable(~stall_pipeline),
		.flush(flush),
		.dataM(dataM),
		.dataM_new(dataM_nxt)
	);

	writeback writeback_inst (
		.clk(clk),
		.reset(reset),
		.dataM(dataM),
		.dataW(dataW)
	);

	
`ifdef VERILATOR
	DifftestInstrCommit DifftestInstrCommit(
		.clock              (clk),
		.coreid             (0),
		.index              (0),
		.valid              (dataW.commit_valid),
		.pc                 (dataW.commit_pc),
		.instr              (dataW.commit_instr),
		.skip               ((dataW.mem & dataW.memaddr[31] == 0)),
		.isRVC              (0),
		.scFailed           (0),
		.wen                (dataW.wvalid),
		.wdest              ({3'b0, dataW.wa}),
		.wdata              (dataW.wd)
	);

	DifftestArchIntRegState DifftestArchIntRegState (
		.clock              (clk),
		.coreid             (0),
		.gpr_0              (difftest_regs[0]),
		.gpr_1              (difftest_regs[1]),
		.gpr_2              (difftest_regs[2]),
		.gpr_3              (difftest_regs[3]),
		.gpr_4              (difftest_regs[4]),
		.gpr_5              (difftest_regs[5]),
		.gpr_6              (difftest_regs[6]),
		.gpr_7              (difftest_regs[7]),
		.gpr_8              (difftest_regs[8]),
		.gpr_9              (difftest_regs[9]),
		.gpr_10             (difftest_regs[10]),
		.gpr_11             (difftest_regs[11]),
		.gpr_12             (difftest_regs[12]),
		.gpr_13             (difftest_regs[13]),
		.gpr_14             (difftest_regs[14]),
		.gpr_15             (difftest_regs[15]),
		.gpr_16             (difftest_regs[16]),
		.gpr_17             (difftest_regs[17]),
		.gpr_18             (difftest_regs[18]),
		.gpr_19             (difftest_regs[19]),
		.gpr_20             (difftest_regs[20]),
		.gpr_21             (difftest_regs[21]),
		.gpr_22             (difftest_regs[22]),
		.gpr_23             (difftest_regs[23]),
		.gpr_24             (difftest_regs[24]),
		.gpr_25             (difftest_regs[25]),
		.gpr_26             (difftest_regs[26]),
		.gpr_27             (difftest_regs[27]),
		.gpr_28             (difftest_regs[28]),
		.gpr_29             (difftest_regs[29]),
		.gpr_30             (difftest_regs[30]),
		.gpr_31             (difftest_regs[31])
	);

    DifftestTrapEvent DifftestTrapEvent(
		.clock              (clk),
		.coreid             (0),
		.valid              (0),
		.code               (0),
		.pc                 (0),
		.cycleCnt           (0),
		.instrCnt           (0)
	);

	DifftestCSRState u_DifftestCSRState (
		.clock          (clk),
		.coreid         (mhartid[7:0]),             // hartid  ? 8  ?
		.priviledgeMode (mode),                   // machine mode = 3
		.mstatus        (mstatus),                  // mstatus
		.sstatus        (mstatus & SSTATUS_MASK),   // sstatus = mstatus & mask
		.mepc           (mepc),                     // mepc
		.sepc           (0),                    // sepc 暂未实现
		.mtval          (mtval),                    // mtval
		.stval          (0),                    // stval 暂未实现
		.mtvec          (mtvec),                    // mtvec
		.stvec          (0),                    // stvec 暂未实现
		.mcause         (mcause),                   // mcause
		.scause         (0),                    // scause 暂未实现
		.satp           (satp),                     // satp
		.mip            (mip),                      // mip
		.mie            (mie),                      // mie
		.mscratch       (mscratch),                 // mscratch
		.sscratch       (0),                    // sscratch 暂未实现
		.mideleg        (0),                    // mideleg 暂未实现
		.medeleg		(0)
		);
`endif
endmodule
`endif