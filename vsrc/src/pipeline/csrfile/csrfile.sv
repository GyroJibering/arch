`ifndef __CSRFILE_SV
`define __CSRFILE_SV

`include "include/common.sv"
`include "include/pipes.sv"   // 定义了指令类型和操作码
`include "include/csr.sv"   // 定义了 CSR_* 编号和各 MASK

module csrfile
  import common::*;
  import pipes::*; 
  import csr_pkg::*;  // 从 csr_pkg 中引入 CSR 地址和掩码
(
  input  logic            clk,
  input  logic            reset,

  // 普通 CSR 读写接口
  input  logic [11:0]     csr_addr_r,
  output logic [XLEN-1:0] csr_rdata,
  input  logic            csr_we,
  input  logic [11:0]     csr_addr_w,
  input  logic [XLEN-1:0] csr_wdata,
  output u1               csr_write_finish,

  // 异常/返回信号
  input  decode_op_t      op,
  input  u1               instr_misaligned, // instruction misaligned
  input  u1               store_misaligned, // store misaligned
  input  u1               load_misaligned,  // load misaligned
  input  u64              cur_pc,         // 触发异常时的 PC
  output u64              nxt_pc,         // 异常返回地址
  output u2               mode,
  output u1               csr_jump_en,    // CSR 使能信号
  output u1               timer_interrupt, 
  // input  u1               int_pend,

  // 对外导出寄存器状态 (给 difftest 等)
  output mstatus_t        mstatus,
  output logic [XLEN-1:0] mtvec,
  input logic [XLEN-1:0] mip,
  output logic [XLEN-1:0] mie,
  output logic [XLEN-1:0] mscratch,
  output logic [XLEN-1:0] mcause,
  output logic [XLEN-1:0] mtval,
  output logic [XLEN-1:0] mepc,
  output logic [XLEN-1:0] mcycle,
  output logic [XLEN-1:0] mhartid,
  output satp_t           satp
);



  u1                ecall;          // ECALL 
  u1                mret;           // MRET 
  logic [62:0]      ecode;        //  (mcause[62:0])
  u1                interrupt_valid; // 
  u1                interrupt;
  interrupt_state_t interrupt_state;

  word_t            mtvec_nxt, mie_nxt, mscratch_nxt, mcause_nxt, mtval_nxt, mepc_nxt, mcycle_nxt;
  satp_t            satp_nxt;
  mstatus_t         mstatus_nxt;

  assign ecall            = (op == ECALL) ? 1'b1 : 1'b0; // ECALL 
  assign mret             = (op == MRET)  ? 1'b1 : 1'b0; // MRET 
  assign interrupt_valid  = (mode == 0) || (mstatus.mie == 1);
  assign timer_interrupt  = interrupt_state == TIMER_INTERRUPT; // 定时器中断

  always_comb begin
      interrupt = 1'b0;
      interrupt_state = INT_NOP;
      if (interrupt_valid) begin
          // 优先级：定时器 > 外部 > 软件
          if (mip[7] && mie[7]) begin           // 定时器中断（位7）
              interrupt = 1'b1;
              interrupt_state = TIMER_INTERRUPT;
          end else if (mip[11] && mie[11]) begin  // 外部中断（位11）
              interrupt = 1'b1;
              interrupt_state = EXTERNAL_INTERRUPT;
          end else if (mip[3] && mie[3]) begin  // 软件中断（位3）
              interrupt = 1'b1;
              interrupt_state = SOFTWARE_INTERRUPT;
          end
      end
  end

  logic interrupt_prev;  // 保存 interrupt 上一个周期的值

  always_ff @(posedge clk or posedge reset) begin
      if (reset) begin
          interrupt_prev <= 1'b0;
      end else begin
          interrupt_prev <= interrupt;  // 每个周期更新一次
      end
  end

  // 上升沿检测信号（时序逻辑）
  logic interrupt_posedge;
  assign interrupt_posedge = interrupt && !interrupt_prev;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      mstatus  <= '0;
      mtvec    <= '0;
      // mip      <= '0;
      mie      <= '0;
      mscratch <= '0;
      mcause   <= '0;
      mtval    <= '0;
      mepc     <= '0;        // 'h7ffff0000;
      satp     <= '0;
      mhartid  <= '0;   // hartid = 0
      mcycle   <= '0;
      mode     <= 2'b11;  // 机器模式
      ecode    <= 63'h0; // 默认异常号
      csr_jump_en <= 1'b0;
      csr_write_finish <= 1'b0;
    end else begin
      // mcycle 始终自增

      mcycle <= mcycle + 1;
      if (interrupt_posedge && ~csr_jump_en) begin  
          mepc         <= cur_pc;               
          mstatus.mpie <= mstatus.mie;     
          mstatus.mie  <= 1'b0;            
          mstatus.mpp  <= mode;           
          nxt_pc       <= mtvec;                
          csr_jump_en  <= 1'b1;            
          case (interrupt_state)
              TIMER_INTERRUPT:    mcause   <= 64'h8000000000000007;
              EXTERNAL_INTERRUPT: mcause   <= 64'h800000000000000B; 
              SOFTWARE_INTERRUPT: mcause   <= 64'h8000000000000003; 
              default: ;
          endcase
      end
      else if (instr_misaligned) begin
          mepc      <= cur_pc;      
          mcause    <= 64'h0;       
          mstatus.mpie <= mstatus.mie;
          mstatus.mie  <= 1'b0;     
          mstatus.mpp  <= mode;
          nxt_pc   <= mtvec;
          // csr_jump_en <= 1'b1; // 使能 CSR 跳转       
      end
      else if (load_misaligned) begin  
          mepc      <= cur_pc;          
          mcause    <= 64'h4;           
          mstatus.mpie <= mstatus.mie;  
          mstatus.mie  <= 1'b0;         
          mstatus.mpp  <= mode;         
          nxt_pc   <= mtvec;
          csr_jump_en <= 1'b1; // 使能 CSR 跳转            
      end
      else if (store_misaligned) begin  
          mepc      <= cur_pc;          
          mcause    <= 64'h6;           
          mstatus.mpie <= mstatus.mie;  
          mstatus.mie  <= 1'b0;         
          mstatus.mpp  <= mode;         
          nxt_pc   <= mtvec;
          csr_jump_en <= 1'b1; // 使能 CSR 跳转            
          // mode            <= 2'b11;  // 设置特权等级
      end
      // ecall
      else if (ecall) begin
        mepc            <= cur_pc;  // 保存当前 PC
        nxt_pc          <= mtvec;  // 设置异常返回地址
        mcause[63]      <= 1'b0;  // 设置异常标志
        // mcause[62:0]    <= mode == 'b11 ? 8 : 11;  // 设置异常号
        case (mode)
            2'b00: mcause[62:0] <= 8;  // U-mode: Environment Call from U-mode
            2'b01: mcause[62:0] <= 9;  // S-mode: Environment Call from S-mode
            2'b11: mcause[62:0] <= 11; // M-mode: Environment Call from M-mode
            default: mcause[62:0] <= 11; // 默认处理为 M-mode
        endcase
        mstatus.mie     <= 1'b0;  // 禁止中断
        mstatus.mpie    <= mstatus.mie;  
        mstatus.mpp     <= mode;  // 保存当前特权等级
        mode            <= 2'b11;  // 设置特权等级
      end
      // mret
      else if (mret) begin
        mstatus.mie     <= mstatus.mpie;  // 恢复中断使能
        mstatus.mpie    <= 1;
        mstatus.mpp     <= mode;
        mode            <= mstatus.mpp;  // 恢复特权等级
        mstatus.xs      <= 0;  // 恢复扩展状态
        nxt_pc          <= mepc;  // 恢复返回地址
      end
      /* else if (csr_we) begin
        csr_write_finish <= 1'b1; // 写操作完成
        unique case (csr_addr_w)
          CSR_MSTATUS:  mstatus_nxt  <= csr_wdata & MSTATUS_MASK;
          CSR_MTVEC:    mtvec_nxt    <= csr_wdata & MTVEC_MASK;
          // CSR_MIP:      mip      <= csr_wdata & MIP_MASK;
          CSR_MIE:      mie_nxt      <= csr_wdata;              // 机器中断使能
          CSR_MSCRATCH: mscratch_nxt <= csr_wdata;
          CSR_MCAUSE:   mcause_nxt   <= csr_wdata;
          CSR_MTVAL:    mtval_nxt    <= csr_wdata;
          CSR_MEPC:     mepc_nxt     <= csr_wdata; 
          CSR_MCYCLE:   mcycle_nxt   <= csr_wdata;              // 写覆盖
          CSR_SATP:     satp_nxt     <= csr_wdata;              // 直存整个 satp 结构
          default:;
        endcase
      end */
      else if (csr_we) begin
        csr_write_finish <= 1'b1; // 写操作完成
        unique case (csr_addr_w)
          CSR_MSTATUS:  mstatus <= csr_wdata & MSTATUS_MASK;
          CSR_MTVEC:    mtvec    <= csr_wdata & MTVEC_MASK;
          // CSR_MIP:      mip      <= csr_wdata & MIP_MASK;
          CSR_MIE:      mie      <= csr_wdata;              // 机器中断使能
          CSR_MSCRATCH: mscratch <= csr_wdata;
          CSR_MCAUSE:   mcause   <= csr_wdata;
          CSR_MTVAL:    mtval    <= csr_wdata;
          CSR_MEPC:     mepc     <= csr_wdata; 
          CSR_MCYCLE:   mcycle   <= csr_wdata;              // 写覆盖
          CSR_SATP:     satp     <= csr_wdata;              // 直存整个 satp 结构
          default:;
        endcase
      end
      else begin 
      csr_jump_en <= 1'b0; 
      csr_write_finish <= 1'b0; 
      end
      
    end
  end

  /* always_ff @(posedge clk or posedge reset) begin
      mstatus  <= mstatus_nxt;
      mtvec    <= mtvec_nxt;
      mie      <= mie_nxt;
      mscratch <= mscratch_nxt;
      mcause   <= mcause_nxt;
      mtval    <= mtval_nxt;
      mepc     <= mepc_nxt;
      mcycle   <= mcycle_nxt;
      satp     <= satp_nxt;
  end */

  always_comb begin
    unique case (csr_addr_r)
      CSR_MSTATUS:  csr_rdata = mstatus;
      CSR_SSTATUS:  csr_rdata = mstatus & SSTATUS_MASK;
      CSR_MTVEC:    csr_rdata = mtvec;
      // CSR_MIP:      csr_rdata = mip;
      CSR_MIE:      csr_rdata = mie;
      CSR_MSCRATCH: csr_rdata = mscratch;
      CSR_MCAUSE:   csr_rdata = mcause;
      CSR_MTVAL:    csr_rdata = mtval;
      CSR_MEPC:     csr_rdata = mepc;
      CSR_MCYCLE:   csr_rdata = mcycle;
      CSR_MHARTID:  csr_rdata = mhartid;
      CSR_SATP:     csr_rdata = satp;
      default:      csr_rdata = '0;
    endcase
  end


  /* always_ff @(posedge clk) begin
		if (interrupt_state == TIMER_INTERRUPT) begin
			$display("time interrupt in : %h", cur_pc);
		end
	end */

endmodule

`endif

