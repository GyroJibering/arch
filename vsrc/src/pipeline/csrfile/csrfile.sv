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

  // 异常/返回信号
  input  decode_op_t      op,
 
  input  u64              cur_pc,         // 触发异常时的 PC
  output u64              nxt_pc,         // 异常返回地址
  output u2               mode,
  

  // 对外导出寄存器状态 (给 difftest 等)
  output mstatus_t        mstatus,
  output logic [XLEN-1:0] mtvec,
  output logic [XLEN-1:0] mip,
  output logic [XLEN-1:0] mie,
  output logic [XLEN-1:0] mscratch,
  output logic [XLEN-1:0] mcause,
  output logic [XLEN-1:0] mtval,
  output logic [XLEN-1:0] mepc,
  output logic [XLEN-1:0] mcycle,
  output logic [XLEN-1:0] mhartid,
  output satp_t           satp
);



  u1  ecall;          // ECALL 异常到来
  u1  mret;           // MRET 返回
  logic [62:0]     ecode;        // 异常号 (mcause[62:0])



  assign ecall = (op == ECALL) ? 1'b1 : 1'b0; // ECALL 异常
  assign mret  = (op == MRET)  ? 1'b1 : 1'b0; // MRET 返回

  // ----------------------------------------------------------------------------
  // 同步逻辑：mcycle 增量、正常 CSR 写，以及 ECALL/MRET 特殊处理
  // ----------------------------------------------------------------------------
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      mstatus  <= '0;
      mtvec    <= '0;
      mip      <= '0;
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
    end else begin
      // mcycle 始终自增
      mcycle <= mcycle + 1;
      if (cur_pc == 64'h7ffff0008) begin
        ecode <= 63'h8; // 设置异常号
      end
      // **最高优先级：ECALL 异常**
      if (ecall) begin
        mepc            <= cur_pc;  // 保存当前 PC
        nxt_pc          <= mtvec;  // 设置异常返回地址
        mcause[63]      <= 1'b0;  // 设置异常标志
        mcause[62:0]    <= ecode;  // 设置异常号
        mstatus.mie     <= 1'b0;  // 禁止中断
        mstatus.mpie    <= mstatus.mie;  
        mstatus.mpp     <= mode;  // 保存当前特权等级
        mode            <= 2'b11;  // 设置特权等级
      end
      // **次优先：MRET 返回**
      else if (mret) begin
        mstatus.mie     <= mstatus.mpie;  // 恢复中断使能
        mstatus.mpie    <= 1;
        mstatus.mpp     <= 2'b00;
        mode            <= mstatus.mpp;  // 恢复特权等级
        mstatus.xs      <= 0;  // 恢复扩展状态
        nxt_pc          <= mepc;  // 恢复返回地址
      end
      // **普通 CSR 写**
      else if (csr_we) begin
        unique case (csr_addr_w)
          CSR_MSTATUS:  mstatus  <= csr_wdata & MSTATUS_MASK;
          CSR_MTVEC:    mtvec    <= csr_wdata & MTVEC_MASK;
          CSR_MIP:      mip      <= csr_wdata & MIP_MASK;
          CSR_MIE:      mie      <= csr_wdata;              // 机器中断使能
          CSR_MSCRATCH: mscratch <= csr_wdata;
          CSR_MCAUSE:   mcause   <= csr_wdata;
          CSR_MTVAL:    mtval    <= csr_wdata;
          CSR_MEPC:     mepc     <= csr_wdata; 
          CSR_MCYCLE:   mcycle   <= csr_wdata;              // 写覆盖
          CSR_SATP:     satp     <= csr_wdata;              // 直存整个 satp 结构
          default: /* 其它 CSR 不写 */;
        endcase
      end
    end
  end

  always_comb begin
    unique case (csr_addr_r)
      CSR_MSTATUS:  csr_rdata = mstatus;
      CSR_SSTATUS:  csr_rdata = mstatus & SSTATUS_MASK;
      CSR_MTVEC:    csr_rdata = mtvec;
      CSR_MIP:      csr_rdata = mip;
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

endmodule

`endif
