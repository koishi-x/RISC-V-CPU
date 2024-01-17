`include "utils.v"
`include "ID.v"

`ifndef __IFETCH__
`define __IFETCH__

//get and decode instruction from instruction cache
module IFetch(
    input wire clk,
    input wire rst,
    input wire rdy,

    output wire[31:0] pc_to_ic,

    input wire inst_valid,
    input wire[31:0] inst_from_ic,

    output reg inst_send_enable,
    output reg[31:0] pc_to_issue,
    output reg pred_to_issue,
    output reg[`OP_SIZE_LOG - 1:0] op_type_to_issue,
    output reg[4:0] rd_to_issue,
    output reg[31:0] imm_to_issue,
    output reg[4:0] rs1_to_RF,
    output reg[4:0] rs2_to_RF,
    
    input wire jump_flag,
    input wire[31:0] target_pc,

    input wire ROB_full,
    input wire RS_full,
    input wire SLB_full,

    input wire upd_prd_valid,
    input wire[9:2] upd_prd_index,
    input wire upd_prd_isjump
);
    reg[31:0] pc;

    reg[1:0] predictor[255:0];  //2^8-1

    wire[`OP_SIZE_LOG - 1:0] op_type;
    wire[4:0] rs1, rs2, rd;
    wire[31:0] imm;

    assign pc_to_ic = pc;
    InstDecode id(
        .inst(inst_from_ic),
        .op_type(op_type),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm(imm)
    );

    integer i;
    always @(posedge clk) begin
        if (rst) begin 
            pc <= 0;
            inst_send_enable <= 0;
            for (i = 0; i < 256; i = i + 1) predictor[i] <= 0;
        end
        else if (!rdy) begin end
        else begin
            if (upd_prd_valid) begin 
                if (upd_prd_isjump && predictor[upd_prd_index] < 2'b11) 
                    predictor[upd_prd_index] <= predictor[upd_prd_index] + 1;
                else if (!upd_prd_isjump && predictor[upd_prd_index] > 2'b00)
                    predictor[upd_prd_index] <= predictor[upd_prd_index] - 1;
            end

            if (jump_flag) begin
                pc <= target_pc;
                inst_send_enable <= 0;
            end
            else if (ROB_full || RS_full || SLB_full) begin
                inst_send_enable <= 0;
            end
            else if (inst_valid) begin
                inst_send_enable <= 1;
                op_type_to_issue <= op_type;
                pc_to_issue <= pc;
                rd_to_issue <= rd;
                rs1_to_RF <= rs1;
                rs2_to_RF <= rs2;
                imm_to_issue <= imm;

                if (inst_from_ic[6:0] == 7'b1100011 && predictor[pc[9:2]] >= 2'b10) begin  //B-type
                    pred_to_issue <= 1;
                    pc <= pc + imm;
                end
                else begin
                    pred_to_issue <= 0;
                    pc <= pc + 4;
                end
            end
            else begin
                inst_send_enable <= 0;
            end

        end
    end

endmodule

`endif