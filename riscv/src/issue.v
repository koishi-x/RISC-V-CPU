`include "utils.v"

`ifndef __ISSUE__
`define __ISSUE__

module issue(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire inst_valid,
    //input wire[31:0] inst_from_if,
    input wire[`OP_SIZE_LOG - 1:0] op_type,

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
    assign vj = rj_from_rf ? vj_from_rf : rob_rs1_value;
    assign qj = qj_from_rf;
    assign rj = rj_from_rf || rob_rs1_ready;

    assign vk = rk_from_rf ? vk_from_rf : rob_rs2_value;
    assign qk = qk_from_rf;
    assign rk = rk_from_rf || rob_rs2_ready;
    
    always @(*) begin
        if (!rst && rdy && inst_valid) begin
            rob_send_enable <= 1;
            send_robid <= next_robid;
            rf_send_enable <= 1;
            

            if (op_type >= `OP_LB && op_type <= `OP_SW) begin
                slb_send_enable <= 1;
                rs_send_enable <= 0;
            end
            else begin
                slb_send_enable <= 0;
                rs_send_enable <= 1;
            end
        end
        else begin 
            rob_send_enable <= 0;
            rf_send_enable <= 0;
            rs_send_enable <= 0;
            slb_send_enable <= 0;
            send_robid <= 0;
        end
    end
endmodule

`endif

// `include "utils.v"

// `ifndef __ISSUE__
// `define __ISSUE__

// module issue(
//     input wire clk,
//     input wire rst,
//     input wire rdy,

//     input wire inst_valid,
//     //input wire[31:0] inst_from_if,
//     input wire[`OP_SIZE_LOG - 1:0] op_type,

//     input wire[31:0] vj_from_rf,
//     input wire[`ROB_SIZE_LOG - 1:0] qj_from_rf,
//     input wire rj_from_rf,
//     input wire[31:0] vk_from_rf,
//     input wire[`ROB_SIZE_LOG - 1:0] qk_from_rf,
//     input wire rk_from_rf,

//     input wire rob_rs1_ready,
//     input wire[31:0] rob_rs1_value,
//     input wire rob_rs2_ready,
//     input wire[31:0] rob_rs2_value,

//     input wire[`ROB_SIZE_LOG - 1:0] next_robid,
//     output reg rob_send_enable,
//     output reg[`ROB_SIZE_LOG - 1:0] send_robid,

//     output reg rf_send_enable,
//     output reg rs_send_enable,
//     output reg slb_send_enable,

//     output reg[31:0] vj,
//     output reg[`ROB_SIZE_LOG - 1:0] qj,
//     output reg rj,
//     output reg[31:0] vk,
//     output reg[`ROB_SIZE_LOG - 1:0] qk,
//     output reg rk
// );
//     always @(*) begin
//         if (!rst && rdy && inst_valid) begin
//             rob_send_enable <= 1;
//             send_robid <= next_robid;
//             rf_send_enable <= 1;
//             vj <= rj_from_rf ? vj_from_rf : rob_rs1_value;
//             qj <= qj_from_rf;
//             rj <= rj_from_rf || rob_rs1_ready;

//             vk <= rk_from_rf ? vk_from_rf : rob_rs2_value;
//             qk <= qk_from_rf;
//             rk <= rk_from_rf || rob_rs2_ready;

//             if (op_type >= `OP_LB && op_type <= `OP_SW) begin
//                 slb_send_enable <= 1;
//                 rs_send_enable <= 0;
//             end
//             else begin
//                 slb_send_enable <= 0;
//                 rs_send_enable <= 1;
//             end
//         end
//         else begin 
//             rob_send_enable <= 0;
//             rf_send_enable <= 0;
//             rs_send_enable <= 0;
//             slb_send_enable <= 0;
//             send_robid <= 0;
//         end
//     end
// endmodule

// `endif