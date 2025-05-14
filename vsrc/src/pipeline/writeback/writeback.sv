`ifndef __WRITEBACK_SV
`define __WRITEBACK_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module writeback
  import common::*;
  import pipes::*;
(
    input  logic          clk,
    input  logic          reset,
    input  memory_data_t  dataM,          // 来自 MEM 阶段的数据
    output writeback_data_t dataW          // 新增：所有写回相关信号打包
);

  // 1) 统一赋值到 dataW
    assign dataW.wa           = dataM.dst;
    assign dataW.wd           = dataM.ctl.csr ? dataM.csr_rdata : dataM.rd;
    assign dataW.wvalid       = dataM.ctl.csr ? dataM.ctl.regwrite : dataM.reg_write_en;
    assign dataW.commit_pc    = dataM.pc;
    assign dataW.commit_instr = dataM.raw_instr;
    assign dataW.commit_valid = dataM.instr_valid;
    assign dataW.jump_flag    = dataM.jump_flag;
    assign dataW.jump_target  = dataM.jump_target;
    assign dataW.mem          = dataM.mem;
    assign dataW.memaddr      = dataM.memaddr;
    assign dataW.ctl          = dataM.ctl;
    assign dataW.csr_wdata    = dataM.csr_wdata;

endmodule


`endif
