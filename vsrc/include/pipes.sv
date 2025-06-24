`ifndef __PIPES_SV
`define __PIPES_SV

`ifdef VERILATOR
`include "include/common.sv"
`endif

package pipes;
	import common::*;
/* Define instrucion decoding rules here */

// parameter F7_RI = 7'bxxxxxxx;
// I-Type opcode
parameter F7_I_TYPE   = 7'b0010011;
// R-Type opcode
parameter F7_R_TYPE   = 7'b0110011;
// I/W-Type opcode (ADDIW)
parameter F7_IW_TYPE  = 7'b0011011;
// R/W-Type opcode (W-extensions)
parameter F7_RW_TYPE  = 7'b0111011;

// U-Type / LUI opcode
parameter OPC_LUI     = 7'b0110111;
// LOAD opcode
parameter OP_LOAD     = 7'b0000011;
// STORE opcode (S-type)
parameter OP_SD       = 7'b0100011;
// Branch opcode
parameter OP_BRANCH   = 7'b1100011;
// AUIPC opcode
parameter OP_AUIPC    = 7'b0010111;
// JAL opcode
parameter OP_JAL      = 7'b1101111;
// JALR opcode
parameter OP_JALR     = 7'b1100111;
parameter F3_JALR     = 3'b000;

// funct3 for basic I/R-type arithmetic
parameter F3_ADD      = 3'b000;
parameter F3_SUB      = 3'b000;
parameter F3_XOR      = 3'b100;
parameter F3_OR       = 3'b110;
parameter F3_AND      = 3'b111;

// funct7 for basic R-type arithmetic
parameter F7_ADD      = 7'b0000000;
parameter F7_SUB      = 7'b0100000;
parameter F7_XOR      = 7'b0000000;
parameter F7_OR       = 7'b0000000;
parameter F7_AND      = 7'b0000000;
parameter F7_SUBW     = 7'b0100000;
parameter F7_ADDW     = 7'b0000000;

// Load funct3 (RV64I)
parameter F3_LB       = 3'b000;
parameter F3_LH       = 3'b001;
parameter F3_LW       = 3'b010;
parameter F3_LD       = 3'b011;
parameter F3_LBU      = 3'b100;
parameter F3_LHU      = 3'b101;
parameter F3_LWU      = 3'b110;

// Store funct3
parameter F3_SB       = 3'b000;
parameter F3_SH       = 3'b001;
parameter F3_SW       = 3'b010;
parameter F3_SD       = 3'b011;

// Branch funct3
parameter F3_BEQ      = 3'b000;
parameter F3_BNE      = 3'b001;
parameter F3_BLT      = 3'b100;
parameter F3_BGE      = 3'b101;
parameter F3_BLTU     = 3'b110;
parameter F3_BGEU     = 3'b111;

// I-type immediate arithmetic funct3
parameter F3_SLTI     = 3'b010;
parameter F3_SLTIU    = 3'b011;
parameter F3_SLLI     = 3'b001;
parameter F3_SRLI     = 3'b101;
parameter F3_SRAI     = 3'b101;
parameter F7_SRAI     = 7'b0100000;

// R-type arithmetic funct3 for shifts and comparisons
parameter F3_SLL      = 3'b001;
parameter F3_SLT      = 3'b010;
parameter F3_SLTU     = 3'b011;
parameter F3_SRL      = 3'b101;
parameter F3_SRA      = 3'b101;
parameter F7_SRA      = 7'b0100000;

// W-extension immediate instructions funct3
parameter F3_SLLIW    = 3'b001;
parameter F3_SRLIW    = 3'b101;
parameter F3_SRAIW    = 3'b101;
parameter F7_SRAIW    = 7'b0100000;

// W-extension R-type arithmetic funct3
parameter F3_SLLW     = 3'b001;
parameter F3_SRLW     = 3'b101;
parameter F3_SRAW     = 3'b101;
parameter F7_SRAW     = 7'b0100000;

// Additional R-type funct7 for shifts and comparisons
parameter F7_SLL      = 7'b0000000;
parameter F7_SLT      = 7'b0000000;
parameter F7_SLTU     = 7'b0000000;
parameter F7_SRL      = 7'b0000000;

// Additional W-extension funct7 definitions (if needed)
parameter F7_SLLW     = 7'b0000000;
parameter F7_SRLW     = 7'b0000000;

parameter F6_SRAI     = 6'b010000;
parameter F6_SRLIW    = 6'b000000;
parameter F6_SRAIW    = 6'b010000;

parameter OP_SYSTEM  = 7'b1110011;
parameter F3_CSRRW   = 3'b001;
parameter F3_CSRRS   = 3'b010;
parameter F3_CSRRC   = 3'b011;
parameter F3_CSRRWI  = 3'b101;
parameter F3_CSRRSI  = 3'b110;
parameter F3_CSRRCI  = 3'b111;
parameter F3_ECALL   = 3'b000;

// mmu.sv used parameters
parameter int VPN_BITS    = 27;
parameter int PPN_BITS    = 44;
parameter int PAGE_LEVELS = 3;
parameter int ASID_BITS   = 16;
parameter int TLB_WAYS    = 4;
parameter int TLB_SETS    = 64;


typedef struct packed {
    u64 pc;
	u32 raw_instr;
    logic instr_valid;
} fetch_data_t;

typedef enum logic [5:0] {
    UNKNOWN,
    ADDI,  XORI,  ORI,   ANDI,  SLTI,
    SLTIU, SLLI,  SRLI,  SRAI,  SLLIW,
    ADD,   SUB,   XOR,   OR,    AND,
    SLL,   SLT,   SLTU,  SRL,   SRA,
    ADDW,  SUBW,  SLLW,  SRLW,  SRAW,
    ADDIW, SRLIW, SRAIW,
    LB,    LH,    LW,    LD,    LBU,
    LHU,   LWU,
    SB,    SH,    SW,    SD,
    BEQ,   BNE,   BLT,   BGE,   BLTU,
    BGEU,
    LUI,   AUIPC,
    JALR,
    JAL,
    CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI,
    CSRRCI,CSRW, ECALL, MRET, EBREAK
} decode_op_t;

typedef enum logic [4:0] {
    ALU_ADD,  ALU_SUB,  ALU_XOR,  ALU_OR,   ALU_AND,
    ALU_SLL,  ALU_SLT,  ALU_SLTU, ALU_SRL,  ALU_SRA,
    ALU_ADDW, ALU_SUBW, ALU_SLLW, ALU_SRLW, ALU_SRAW,
    ALU_ADDIW, ALU_SRLIW, ALU_SRAIW
} alufunc_t;

typedef enum logic [2:0] {
    MMU_DIRECT, PAGE_1, PAGE_2, PAGE_3, MMU_NOP, MMU_GAP
} mmu_state;

typedef enum logic [2:0] {
    TIMER_INTERRUPT,
    EXTERNAL_INTERRUPT,
    SOFTWARE_INTERRUPT,
    INT_NOP
} interrupt_state_t;

typedef struct packed {
    decode_op_t op;        // 操作类型（上面的枚举）
    alufunc_t   alufunc;   // ALU操作码（比如加法、减法、移位等）
    u1          regwrite;  // 是否写寄存器
    u64         pc;
	u32         raw_instr;
    u1          branch;    // 是否为分支指令
    u1          jump;      // 是否为跳转指令（jal, jalr）
    u1          csr;        // 新：1 表示这是条 CSR 指令
    u1          csr_we;     // 新：写 CSR 使能
    u12         csr_addr;   // 新：CSR 地址
} control_t;

typedef struct packed {
	word_t      srca, srcb;
	control_t   ctl;
	creg_addr_t dst; 
    u64         pc;
	u32         raw_instr;
    logic       instr_valid;
    word_t      store_data;
    word_t      jump_target;
    word_t      csr_wdata;
    word_t      csr_rdata;  // 写到 rd 的旧 CSR 值
} decode_data_t;


typedef struct packed {
    word_t      srca, srcb;
    control_t   ctl;
	word_t      alu_result;
	creg_addr_t dst;
	u1          reg_write_en;
	u1          zero_flag;
    u64         pc;
	u32         raw_instr;
    logic       instr_valid;
    word_t      store_data;
    word_t      jump_target;
    u1          jump_flag;
    u1          mem;
    word_t      memaddr;
    u1          csr;        // 新：1 表示这是条 CSR 指令
    u1          csr_we;     // 新：写 CSR 使能
    u12         csr_addr;   // 新：CSR 地址
    word_t      csr_wdata;
    word_t      csr_rdata;  // 写到 rd 的旧 CSR 值
} execute_data_t;


typedef struct packed {
	word_t rd;
	creg_addr_t dst;
	u1 reg_write_en;
    u64 pc;
	u32 raw_instr;
    logic instr_valid;
    word_t jump_target;
    u1 jump_flag;
    u1 mem;
    word_t memaddr;
    control_t   ctl;
    word_t      csr_wdata;
    word_t      csr_rdata;  // 写到 rd 的旧 CSR 值
} memory_data_t;

typedef struct packed {
    creg_addr_t  wa;
    word_t       wd;
    logic        wvalid;
    u64          commit_pc;
    u32          commit_instr;
    logic        commit_valid;
    u1           jump_flag;
    word_t       jump_target;
    u1           mem;
    word_t       memaddr;
    control_t    ctl;
    word_t       csr_wdata;
} writeback_data_t;


endpackage

`endif

