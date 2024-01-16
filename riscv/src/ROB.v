`include "utils.v"

`ifndef __ROB__
`define __ROB__

module ROB(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire issue_valid,
    input wire[`OP_SIZE_LOG - 1:0] issue_op_type,
    input wire[4:0] issue_dest,
    input wire[31:0] issue_pc,
    input wire issue_pred,

    input wire ALU_valid,
    input wire[31:0] ALU_value,
    input wire[`ROB_SIZE_LOG - 1:0] ALU_robid,
    input wire[31:0] ALU_topc,

    input wire SLB_load_valid,
    input wire[31:0] SLB_load_value,
    input wire[`ROB_SIZE_LOG - 1:0] SLB_load_robid,
    input wire SLB_store_valid,
    input wire[`ROB_SIZE_LOG - 1:0] SLB_store_robid,

    output reg commit_enable,
    output reg[4:0] commit_regid,
    output reg[31:0] commit_value,
    output reg[`ROB_SIZE_LOG - 1:0] commit_robid,

    output reg pred_fail_flag,
    output reg[31:0] toPc_to_if,
    output reg upd_prd_enable,
    output reg[9:2] upd_prd_index,
    output reg upd_prd_isjump,

    output reg slb_store_enable,
    output reg[`ROB_SIZE_LOG - 1:0] slb_store_begin_robid,

    input wire[`ROB_SIZE_LOG - 1:0] rs1_query_from_issue,
    input wire[`ROB_SIZE_LOG - 1:0] rs2_query_from_issue,
    output wire rs1_ready,
    output wire[31:0] rs1_value,
    output wire rs2_ready,
    output wire[31:0] rs2_value,

    output wire rob_next_full,
    output wire[`ROB_SIZE_LOG - 1:0] rob_nextid,
    output wire[`ROB_SIZE_LOG - 1:0] rob_frontid
);
    reg[`ROB_SIZE_LOG - 1:0] head, tail;    //a queue, range from (head,tail]
    reg is_ready[`ROB_SIZE - 1:0];
    reg[`OP_SIZE_LOG - 1:0] op_type[`ROB_SIZE - 1:0];
    reg[4:0] rd[`ROB_SIZE - 1:0];
    reg[31:0] value[`ROB_SIZE - 1:0];
    reg[31:0] to_pc[`ROB_SIZE - 1:0];
    reg[31:0] cur_pc[`ROB_SIZE - 1:0];
    reg pred[`ROB_SIZE - 1:0];

    wire is_empty = head == tail;
    wire[`ROB_SIZE_LOG - 1:0] front = (head + 1) & (`ROB_SIZE - 1);
    assign rob_frontid = front;
    assign rob_nextid = (tail + 1) & (`ROB_SIZE - 1);
    assign rob_next_full = tail >= head ? tail - head + issue_valid - (rdy && !is_empty && is_ready[front]) >= `ROB_SIZE - 1
        : tail + `ROB_SIZE - head + issue_valid - (rdy && !is_empty && is_ready[front]) >= `ROB_SIZE - 1;

    assign rs1_ready = is_ready[rs1_query_from_issue];
    assign rs1_value = value[rs1_query_from_issue];
    assign rs2_ready = is_ready[rs2_query_from_issue];
    assign rs2_value = value[rs2_query_from_issue];

    integer i;
    always @(posedge clk) begin
        if (rst || pred_fail_flag) begin
            head <= 0;
            tail <= 0;  //clear the ROB
            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                is_ready[i] <= 0;
                to_pc[i] <= -1;
                value[i] <= 0;
            end
            pred_fail_flag <= 0;
            commit_enable <= 0;
            upd_prd_enable <= 0;
            slb_store_enable <= 0;
        end
        else if (!rdy) begin end
        else begin
            if (issue_valid) begin  //issue the instruction into rob
                is_ready[rob_nextid] <= 0;
                op_type[rob_nextid] <= issue_op_type;
                rd[rob_nextid] <= issue_dest;
                pred[rob_nextid] <= issue_pred;
                to_pc[rob_nextid] <= -1;     //to_pc=-1 means to_pc = cur_pc + 4
                cur_pc[rob_nextid] <= issue_pc;
                tail <= rob_nextid;
            end
            if (ALU_valid) begin
                is_ready[ALU_robid] <= 1;
                value[ALU_robid] <= ALU_value;
                to_pc[ALU_robid] <= ALU_topc;
            end
            if (SLB_load_valid) begin
                is_ready[SLB_load_robid] <= 1;
                value[SLB_load_robid] <= SLB_load_value;
            end
            if (SLB_store_valid) begin
                is_ready[SLB_store_robid] <= 1;
            end

            pred_fail_flag <= 0;
            commit_enable <= 0;
            upd_prd_enable <= 0;
            slb_store_enable <= 0;
            if (!is_empty && is_ready[front]) begin
                if (op_type[front] >= `OP_BEQ && op_type[front] <= `OP_BGEU) begin    //B-type
                    upd_prd_enable <= 1;
                    upd_prd_index <= cur_pc[front][9:2];
                    //upd_prd_isjump <= value[front] == 1;
                    upd_prd_isjump <= (value[front] == 1);
                    if (value[front] == 1 ^ pred[front]) begin
                        pred_fail_flag <= 1;
                        toPc_to_if <= to_pc[front];
                    end
                end
                else if (op_type[front] >= `OP_SB && op_type[front] <= `OP_SW) begin
                    slb_store_enable <= 1;
                    slb_store_begin_robid <= front;
                end
                else begin
                    if (~to_pc[front] != 0) begin
                        pred_fail_flag <= 1;
                        toPc_to_if <= to_pc[front];
                    end
                    commit_enable <= 1;
                    commit_regid <= rd[front];
                    commit_robid <= front;
                    commit_value <= value[front];
                end
                
                is_ready[front] <= 0;
                head <= (head + 1) & (`ROB_SIZE - 1);
            end
        end
    end
endmodule

`endif