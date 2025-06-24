# arch-2025
RISC-V 五级流水线 CPU 设计
本项目实现了一个完整的 RISC-V 64位五级流水线 CPU，支持 RV64IMAC 指令集，并实现了中断处理、异常处理和特权模式管理等功能。

## 已实现功能
### 基础指令支持 
​​整数运算指令​​：addi, xori, ori, andi, add, sub, and, or, xor
​​扩展指令​​：addiw, addw, subw
​​### 五级流水线架构​​：取指(IF)、译码(ID)、执行(EX)、访存(MEM)、写回(WB)
### 内存访问指令 
​​加载指令​​：ld, lw, lh, lb, lwu, lhu, lbu
​​存储指令​​：sd, sw, sh, sb
​​地址计算指令​​：lui
### 控制流指令 
​​条件分支​​：beq, bne, blt, bge, bltu, bgeu
​​移位操作​​：slli, srli, srai, sll, srl, sra
​​比较指令​​：slti, sltiu, slt, sltu
​​扩展移位​​：slliw, srliw, sraiw, sllw, srlw, sraw
​​跳转指令​​：auipc, jalr, jal
### CSR 寄存器支持 
​​CSR 指令​​：CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
​​实现 CSR 寄存器​​：
寄存器	功能描述
mstatus	机器模式状态寄存器
mtvec	机器模式异常处理基地址
mip	机器模式中断挂起寄存器
mie	机器模式中断使能寄存器
mscratch	机器模式暂存寄存器
mcause	机器模式异常原因寄存器
mtval	机器模式异常值寄存器
mepc	机器模式异常程序计数器
mcycle	机器模式周期计数器
mhartid	机器模式硬件线程ID（固定为0）
satp	监管地址转换和物理内存保护寄存器
​​Difftest 连接​​：与 DifftestCSRState 集成
### 特权指令支持 
​​环境调用指令​​：ECALL
​​特权返回指令​​：MRET
​​乘法指令​​：MUL（通过扩展实现）
### 中断与异常处理 
​​特权模式​​：机器模式(M-mode)
​​中断类型​​：
定时器中断 (TIMER_INTERRUPT)
软件中断 (SOFTWARE_INTERRUPT)
外部中断 (EXTERNAL_INTERRUPT)
​​异常类型​​：
非法指令异常
非法地址异常
地址不对齐异常
​​中断处理流程​​：
保存当前 PC 到 mepc
更新 mstatus 状态位
设置中断原因到 mcause
跳转到 mtvec 地址
执行中断服务程序
MRET 返回
## 关键技术特性
​​精确中断处理​​
中断上升沿触发
完整上下文保存与恢复
中断优先级管理
​​PC 历史跟踪​​
实时维护最近5条指令的PC值
通过CSR接口可访问历史PC
