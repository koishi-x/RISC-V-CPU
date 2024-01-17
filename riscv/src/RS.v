`include "utils.v"

`ifndef __RS__
`define __RS__

module RS(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire issue_valid,
    input wire[`OP_SIZE_LOG - 1:0] issue_op_type,
    input wire[31:0] issue_vj,
    input wire[`ROB_SIZE_LOG - 1:0] issue_qj,
    input wire issue_rj,
    input wire[31:0] issue_vk,
    input wire[`ROB_SIZE_LOG - 1:0] issue_qk,
    input wire issue_rk,
    input wire[31:0] issue_imm,
    input wire[`ROB_SIZE_LOG - 1:0] issue_robid,
    input wire[31:0] issue_curPc,

    input wire ALU_valid,
    input wire[31:0] ALU_value,
    input wire[`ROB_SIZE_LOG - 1:0] ALU_robid,
    
    input wire SLB_load_valid,
    input wire[31:0] SLB_load_value,
    input wire[`ROB_SIZE_LOG - 1:0] SLB_load_robid,

    output reg ALU_enable,
    output reg[`OP_SIZE_LOG - 1:0] op_to_ALU,
    output reg[31:0] vj_to_ALU,
    output reg[31:0] vk_to_ALU,
    output reg[31:0] imm_to_ALU,
    output reg[`ROB_SIZE_LOG - 1:0] robid_to_ALU,
    output reg[31:0] curpc_to_ALU,

    input wire pred_fail_flag,
    output reg RS_next_full
);
    reg is_busy[`RS_SIZE - 1:0];
    reg[`OP_SIZE_LOG - 1:0] op_type[`RS_SIZE - 1:0];
    reg[31:0] vj[`RS_SIZE - 1:0];
    reg[`ROB_SIZE_LOG - 1:0] qj[`RS_SIZE - 1:0];
    reg rj[`RS_SIZE - 1:0];
    reg[31:0] vk[`RS_SIZE - 1:0];
    reg[`ROB_SIZE_LOG - 1:0] qk[`RS_SIZE - 1:0];
    reg rk[`RS_SIZE - 1:0];
    reg[31:0] imm[`RS_SIZE - 1:0];
    reg[`ROB_SIZE_LOG - 1:0] dest_robid[`RS_SIZE - 1:0];
    reg[31:0] cur_pc[`RS_SIZE - 1:0];


    reg has_ready;
    integer i, busy_cnt, ready_pos, empty_pos;
    always @(*) begin
        busy_cnt = 0;
        ready_pos = -1;
        empty_pos = -1;
        has_ready = 0;
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            if (is_busy[i]) begin
                busy_cnt = busy_cnt + 1;
                if (rj[i] && rk[i]) begin
                    has_ready = 1;
                    ready_pos = i;
                end
            end
            else begin
                empty_pos = i;
            end
        end

        RS_next_full = busy_cnt + issue_valid - has_ready >= `RS_SIZE;
    end

    //integer j;
    always @(posedge clk) begin
        if (rst || pred_fail_flag) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                is_busy[i] <= 0;
                rj[i] <= 0;
                rk[i] <= 0;
            end
            ALU_enable <= 0;
        end
        else if (!rdy) begin end
        else begin
            if (issue_valid) begin
                is_busy[empty_pos] <= 1;
                op_type[empty_pos] <= issue_op_type;
                vj[empty_pos] <= issue_vj;
                qj[empty_pos] <= issue_qj;
                rj[empty_pos] <= issue_rj;
                vk[empty_pos] <= issue_vk;
                qk[empty_pos] <= issue_qk;
                rk[empty_pos] <= issue_rk;
                imm[empty_pos] <= issue_imm;
                dest_robid[empty_pos] <= issue_robid;
                cur_pc[empty_pos] <= issue_curPc;

                // if (ALU_valid) begin
                //     if (!issue_rj && issue_qj == ALU_robid) begin
                //         rj[empty_pos] <= 1;
                //         vj[empty_pos] <= ALU_value;
                //     end
                //     if (!issue_rk && issue_qk == ALU_robid) begin
                //         rk[empty_pos] <= 1;
                //         vk[empty_pos] <= ALU_value;
                //     end
                // end
                // if (SLB_load_valid) begin
                //     if (!issue_rj && issue_qj == SLB_load_robid) begin
                //         rj[empty_pos] <= 1;
                //         vj[empty_pos] <= SLB_load_value;
                //     end
                //     if (!issue_rk && issue_qk == SLB_load_robid) begin
                //         rk[empty_pos] <= 1;
                //         vk[empty_pos] <= SLB_load_value;
                //     end
                // end

                // case(issue_op_type)
                //     `OP_LUI, `OP_AUIPC, `OP_JAL: begin
                //         rj[empty_pos] <= 1;
                //         rk[empty_pos] <= 1;
                //     end
                //     `OP_JALR, `OP_ADDI, `OP_SLTI, `OP_SLTIU, `OP_XORI, `OP_ORI, `OP_ANDI, `OP_SLLI, `OP_SRLI, `OP_SRAI: begin
                //         rk[empty_pos] <= 1;
                //     end
                // endcase

            end
            if (has_ready) begin
                ALU_enable <= 1;
                op_to_ALU <= op_type[ready_pos];
                vj_to_ALU <= vj[ready_pos];
                vk_to_ALU <= vk[ready_pos];
                imm_to_ALU <= imm[ready_pos];
                robid_to_ALU <= dest_robid[ready_pos];
                curpc_to_ALU <= cur_pc[ready_pos];
                is_busy[ready_pos] <= 0;
                //has_ready <= 0;
            end 
            else ALU_enable <= 0;
            
            if (ALU_valid) begin 
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (is_busy[i]) begin
                        if (!rj[i] && qj[i] == ALU_robid) begin
                            rj[i] <= 1;
                            vj[i] <= ALU_value;
                        end
                        if (!rk[i] && qk[i] == ALU_robid) begin
                            rk[i] <= 1;
                            vk[i] <= ALU_value;
                        end
                    end
                end
            end

            if (SLB_load_valid) begin
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (is_busy[i]) begin
                        if (!rj[i] && qj[i] == SLB_load_robid) begin
                            rj[i] <= 1;
                            vj[i] <= SLB_load_value;
                        end
                        if (!rk[i] && qk[i] == SLB_load_robid) begin
                            rk[i] <= 1;
                            vk[i] <= SLB_load_value;
                        end
                    end
                end
            end
        end
    end

endmodule

`endif