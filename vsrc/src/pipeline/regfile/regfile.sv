`ifndef __REGFILE_SV
`define __REGFILE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`endif

module regfile 
    import common::*;
    import pipes::*;(
    input  u1  clk,
    input  u1  reset,
    input  u5  ra1,
    input  u5  ra2,
    output u64 rd1,
    output u64 rd2,
    input  u1  wvalid,
    input  u5  wa,
    input  u64 wd,
    output logic [63:0] difftest_regs[31:0]
);

  // 寄存器堆定义
  u64 regs [31:0];
  u64 next_regs[31:0];

  // 组合逻辑读端口
  assign rd1 = (ra1 == 5'd0) ? 64'd0 : regs[ra1];
  assign rd2 = (ra2 == 5'd0) ? 64'd0 : regs[ra2];

  // 组合逻辑写前传播
  always_comb begin
    next_regs = regs;  // 默认保持当前值
    
    if (wvalid && wa != 5'd0) begin
      next_regs[wa] = wd;  // 写操作传播
    end
  end

  // 时序逻辑（包含异步复位）
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      regs <= '{default:0};  // 异步复位
    end else begin
      regs <= next_regs;     // 正常更新
    end
  end

  // 调试信号连接实际寄存器值
  assign difftest_regs = next_regs;

endmodule

`endif