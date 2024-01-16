`include "utils.v"

`ifndef __REGFILE__
`define __REGFILE__

module reg_file (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire[4:0] rs1,
    input wire[4:0] rs2,

    output wire[31:0] vj,
    output wire[`ROB_SIZE_LOG - 1:0] qj,
    output wire rj,   //1 for ready, 0 for not ready
    output wire[31:0] vk,
    output wire[`ROB_SIZE_LOG - 1:0] qk,
    output wire rk,

    input wire commit_valid,    //commit to reg file
    input wire[4:0] commit_regid,
    input wire[31:0] commit_value,
    input wire[`ROB_SIZE_LOG - 1:0] commit_robid,

    input wire rename_valid,
    input wire[4:0] rename_regid,
    input wire[`ROB_SIZE_LOG - 1:0] rename_robid,

    input wire pred_fail_flag
);
    reg[31:0] reg_value[31:0];
    reg[`ROB_SIZE_LOG - 1:0] rf[31:0];
    reg is_rename[31:0];

    assign vj = (is_rename[rs1] && commit_valid && commit_robid == rf[rs1]) ? commit_value : reg_value[rs1];
    assign qj = rf[rs1];
    assign rj = !is_rename[rs1] || (commit_valid && commit_robid == rf[rs1]);

    assign vk = (is_rename[rs2] && commit_valid && commit_robid == rf[rs2]) ? commit_value : reg_value[rs2];
    assign qk = rf[rs2];
    assign rk = !is_rename[rs2] || (commit_valid && commit_robid == rf[rs2]);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg_value[i] <= 0;
                rf[i] <= 0;
                is_rename[i] <= 0;
            end
        end
        else if (!rdy) begin end
        else begin
            if (commit_valid) begin
                if (is_rename[commit_regid] && rf[commit_regid] == commit_robid) begin
                    rf[commit_regid] <= 0;
                    is_rename[commit_regid] <= 0;
                end

                if (commit_regid != 0) begin
                    reg_value[commit_regid] <= commit_value;
                end
                //notice: modify reg_value whether hit or not
            end

            if (pred_fail_flag) begin
                for (i = 0; i < 32; i = i + 1) begin
                    rf[i] <= 0;
                    is_rename[i] <= 0;
                end
            end
            else if (rename_valid) begin
                if (rename_regid != 0) begin
                    rf[rename_regid] <= rename_robid;
                    is_rename[rename_regid] <= 1;
                end
            end
        end
    end

endmodule

`endif