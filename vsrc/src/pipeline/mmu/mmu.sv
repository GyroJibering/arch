`ifndef __MMU_SV
`define __MMU_SV

`ifdef VERILATOR
  `include "include/common.sv"
  `include "include/pipes.sv"
  `include "include/csr.sv"
`endif

module mmu 
    import common::*;
    import pipes::*;
    import csr_pkg::*;(
        input   u1              clk, reset,
        input   u2              privilegeMode,
        input   dbus_resp_t     dresp,
        input   u64             i_addr,
        input   u1              i_valid,
        output  ibus_req_t      ireq,
        input   ibus_resp_t     iresp,
        input   decode_op_t     op,
        input   dbus_req_t      tmp_dreq,

        output  dbus_req_t      dreq,
        output  dbus_resp_t     tmp_dresp,
        input   satp_t          satp,
        output  ibus_resp_t     tmp_iresp,
        output  logic           stall_mmu
      );
      
       
      mmu_state  state;
      u64 addr;
      

      always_comb begin
          if (tmp_dreq.valid) addr = tmp_dreq.addr;
          else if (i_valid) addr = i_addr;
          else addr = 'b0; 
      end
      
      always @(posedge clk, posedge reset) begin
          if (reset) begin
            state   <= MMU_NOP;
            tmp_iresp  <= '0;
            tmp_dresp  <= '0;
            dreq       <= '0;
            ireq.addr  <= 64'h8000_0000;
            ireq.valid <= 1'b1;
            stall_mmu  <= 1'b0;
          end
          else begin
              case (state)
                  MMU_DIRECT: begin
                      if (dreq.valid & dresp.data_ok) begin 
                        state  <= MMU_GAP; 
                        tmp_dresp <= dresp; 
                        tmp_iresp <= 'b0;
                        dreq.valid  <= 0; 
                        stall_mmu <= 1'b0;
                      end
                      else if (ireq.valid & iresp.data_ok) begin 
                        state       <= MMU_GAP; 
                        // instr   <= iresp.data; 
                        tmp_iresp   <= iresp;
                        tmp_dresp   <= 'b0;
                        ireq.valid  <= 0;
                        stall_mmu   <= 1'b0;
                      end
                  end

                  PAGE_1: begin
                        if (dresp.data_ok) begin 
                            state       <= PAGE_2; 
                            dreq.valid  <= 1; 
                            dreq.addr   <= {8'b0, dresp.data[53:10], addr[29:21], 3'b0}; dreq.size   <= MSIZE8;
                            dreq.strobe <= 'b0;
                            dreq.data   <= 'b0;
                            
                        end
                  end
                  
                  PAGE_2: begin
                      if (dresp.data_ok) begin
                          state       <= PAGE_3;
                          dreq.valid  <= 1;
                          dreq.addr   <= {8'b0, dresp.data[53:10], addr[20:12], 3'b0};
                          dreq.size   <= MSIZE8;
                          dreq.strobe <= 'b0;
                          dreq.data   <= 'b0;
                      end
                  end
                  
                  PAGE_3: begin
                      if (dresp.data_ok) begin
                          state   <= MMU_DIRECT;
                          if (tmp_dreq.valid) begin
                              dreq.valid  <= tmp_dreq.valid;
                              dreq.addr   <= {8'b0, dresp.data[53:10], tmp_dreq.addr[11:0]};
                              dreq.size   <= tmp_dreq.size;
                              dreq.strobe <= tmp_dreq.strobe;
                              dreq.data   <= tmp_dreq.data;
                              ireq.valid  <= 0;
                          end
                          else if (i_valid) begin
                              dreq.valid  <= 0;
                              ireq.valid  <= 1;
                              ireq.addr   <= {8'b0, dresp.data[53:10], i_addr[11:0]};
                          end
                      end
                  end

                  MMU_NOP: begin
                      if (i_valid | tmp_dreq.valid) begin
                          if ((satp.mode == 8) & (privilegeMode != 3))  begin
                              state   <= PAGE_1;
                              dreq.valid  <= 1;
                              dreq.addr   <= {8'b0, satp.ppn, addr[38:30], 3'b0};
                              dreq.size   <= MSIZE8;
                              dreq.strobe <= 'b0;
                              dreq.data   <= 'b0;
                              stall_mmu <= 1'b1;
                          end
                          else begin
                              state   <= MMU_DIRECT;
                              if (tmp_dreq.valid) begin
                                  dreq    <= tmp_dreq;
                              end
                              if (i_valid) begin
                                  ireq.valid  <= 1;
                                  ireq.addr   <= i_addr;
                              end
                          end
                      end
                  end
                  MMU_GAP: begin
                    tmp_dresp <= 'b0;
                    tmp_iresp <= 'b0;
                    if (ireq.valid) state <= MMU_DIRECT;
                    else state <= MMU_NOP;
                  end
                  default: state <= MMU_NOP;
              endcase
          end
      end
endmodule   

`endif
