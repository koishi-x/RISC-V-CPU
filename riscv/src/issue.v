`include "utils.v"

`ifndef __ISSUE__
`define __ISSUE__

module issue(
    input wire rst,
    input wire rdy,

    input wire inst_valid,
    input wire[`OP_SIZE_LOG - 1:0] op_type,

    input wire ALU_valid,
    input wire[31:0] ALU_value,
    input wire[`ROB_SIZE_LOG - 1:0] ALU_robid,
    input wire SLB_load_valid,
    input wire[31:0] SLB_load_value,
    input wire[`ROB_SIZE_LOG - 1:0] SLB_load_robid,


    input wire[31:0] vj_from_rf,
    input wire[`ROB_SIZE_LOG - 1:0] qj_from_rf,
    input wire rj_from_rf,
    input wire[31:0] vk_from_rf,
    input wire[`ROB_SIZE_LOG - 1:0] qk_from_rf,
    input wire rk_from_rf,

    input wire rob_rs1_ready,
    input wire[31:0] rob_rs1_value,
    input wire rob_rs2_ready,
    input wire[31:0] rob_rs2_value,

    input wire[`ROB_SIZE_LOG - 1:0] next_robid,
    output reg rob_send_enable,
    output reg[`ROB_SIZE_LOG - 1:0] send_robid,

    output reg rf_send_enable,
    output reg rs_send_enable,
    output reg slb_send_enable,

    output wire[31:0] vj,
    output wire[`ROB_SIZE_LOG - 1:0] qj,
    output wire rj,
    output wire[31:0] vk,
    output wire[`ROB_SIZE_LOG - 1:0] qk,
    output wire rk
);
    // assign vj = rj_from_rf ? vj_from_rf : rob_rs1_value;
    // assign qj = qj_from_rf;
    // assign rj = rj_from_rf || rob_rs1_ready;

    // assign vk = rk_from_rf ? vk_from_rf : rob_rs2_value;
    // assign qk = qk_from_rf;
    // assign rk = rk_from_rf || rob_rs2_ready;
    assign vj = rj_from_rf ? vj_from_rf : (rob_rs1_ready ? rob_rs1_value : (ALU_valid && ALU_robid == qj_from_rf ? ALU_value : SLB_load_value));
    assign qj = qj_from_rf;
    assign rj = rj_from_rf || rob_rs1_ready || (ALU_valid && ALU_robid == qj_from_rf) || (SLB_load_valid && SLB_load_robid == qj_from_rf);

    assign vk = rk_from_rf ? vk_from_rf : (rob_rs2_ready ? rob_rs2_value : (ALU_valid && ALU_robid == qk_from_rf ? ALU_value : SLB_load_value));
    assign qk = qk_from_rf;
    assign rk = rk_from_rf || rob_rs2_ready || (ALU_valid && ALU_robid == qk_from_rf) || (SLB_load_valid && SLB_load_robid == qk_from_rf);
    
    always @(*) begin
        rob_send_enable = 0;
        rf_send_enable = 0;
        rs_send_enable = 0;
        slb_send_enable = 0;
        send_robid = 0;
        if (!rst && rdy && inst_valid) begin
            rob_send_enable = 1;
            rf_send_enable = 1;
            send_robid = next_robid;
            if (op_type >= `OP_LB && op_type <= `OP_SW) begin
                slb_send_enable = 1;
            end
            else begin
                rs_send_enable = 1;
            end
        end
    end
    // always @(*) begin
    //     if (!rst && rdy && inst_valid) begin
    //         rob_send_enable <= 1;
    //         send_robid <= next_robid;
    //         rf_send_enable <= 1;
            

    //         if (op_type >= `OP_LB && op_type <= `OP_SW) begin
    //             slb_send_enable <= 1;
    //             rs_send_enable <= 0;
    //         end
    //         else begin
    //             slb_send_enable <= 0;
    //             rs_send_enable <= 1;
    //         end
    //     end
    //     else begin 
    //         rob_send_enable <= 0;
    //         rf_send_enable <= 0;
    //         rs_send_enable <= 0;
    //         slb_send_enable <= 0;
    //         send_robid <= 0;
    //     end
    // end
endmodule

`endif