`include "utils.v"

`ifndef __ALU__
`define __ALU__

module alu (
    input wire rst,
    input wire rdy,
    input wire RS_valid,
    input wire[5:0] RS_op,
    input wire[31:0] RS_vj,
    input wire[31:0] RS_vk,
    input wire[31:0] RS_imm,
    input wire[`ROB_SIZE_LOG - 1:0] RS_ROBid,
    input wire[31:0] RS_curpc,

    output reg CBD_enable,
    output reg[31:0] CBD_value,
    output reg[`ROB_SIZE_LOG - 1:0] CBD_ROBid,
    output reg[31:0] CBD_topc 
);
    always @(*) begin
        CBD_enable = 0;
        CBD_topc = -1;
        CBD_value = 0;
        CBD_ROBid = 0;
        if (!rst && rdy && RS_valid && RS_op != `OP_NULL) begin
            CBD_enable = 1;
            CBD_ROBid = RS_ROBid;
            case (RS_op)
                `OP_LUI: CBD_value = RS_imm;
                `OP_AUIPC: CBD_value = RS_imm + RS_curpc;
                `OP_JAL: begin
                    CBD_value = RS_curpc + 4;
                    CBD_topc = RS_curpc + RS_imm;
                end
                `OP_JALR: begin
                    CBD_value = RS_curpc + 4;
                    CBD_topc = (RS_imm + RS_vj) & 32'hFFFFFFFE;
                end
                `OP_BEQ: begin
                    if (RS_vj == RS_vk) begin
                        CBD_topc = RS_curpc + RS_imm;
                        CBD_value = 1;//value = 1 means jump
                    end else begin
                        CBD_topc = RS_curpc + 4;
                        CBD_value = 0;
                    end
                end
                `OP_BNE: begin
                    if (RS_vj != RS_vk) begin
                        CBD_topc = RS_curpc + RS_imm;
                        CBD_value = 1;
                    end else begin
                        CBD_topc = RS_curpc + 4;
                        CBD_value = 0;
                    end
                end
                `OP_BLT: begin
                    if ($signed(RS_vj) < $signed(RS_vk)) begin
                        CBD_topc = RS_curpc + RS_imm;
                        CBD_value = 1;
                    end else begin
                        CBD_topc = RS_curpc + 4;
                        CBD_value = 0;
                    end
                end
                `OP_BGE: begin
                    if ($signed(RS_vj) >= $signed(RS_vk)) begin
                        CBD_topc = RS_curpc + RS_imm;
                        CBD_value = 1;
                    end else begin
                        CBD_topc = RS_curpc + 4;
                        CBD_value = 0;
                    end
                end
                `OP_BLTU: begin
                    if (RS_vj < RS_vk) begin
                        CBD_topc = RS_curpc + RS_imm;
                        CBD_value = 1;
                    end else begin
                        CBD_topc = RS_curpc + 4;
                        CBD_value = 0;
                    end
                end
                `OP_BGEU: begin
                    if (RS_vj >= RS_vk) begin
                        CBD_topc = RS_curpc + RS_imm;
                        CBD_value = 1;
                    end else begin
                        CBD_topc = RS_curpc + 4;
                        CBD_value = 0;
                    end
                end
                `OP_ADDI: CBD_value = RS_vj + RS_imm;
                `OP_SLTI: CBD_value = $signed(RS_vj) < $signed(RS_imm);
                `OP_SLTIU: CBD_value = (RS_vj < RS_imm);
                `OP_XORI: CBD_value = RS_vj ^ RS_imm;
                `OP_ORI: CBD_value = RS_vj | RS_imm;
                `OP_ANDI: CBD_value = RS_vj & RS_imm;
                `OP_SLLI: CBD_value = RS_vj << RS_imm[4:0];
                `OP_SRLI: CBD_value = RS_vj >> RS_imm[4:0];
                `OP_SRAI: CBD_value = $signed(RS_vj) >>> RS_imm[4:0];
                `OP_ADD: CBD_value = RS_vj + RS_vk;
                `OP_SUB: CBD_value = RS_vj - RS_vk;
                `OP_SLL: CBD_value = RS_vj <<< RS_vk[4:0];
                `OP_SLT: CBD_value = ($signed(RS_vj) < $signed(RS_vk));
                `OP_SLTU: CBD_value = (RS_vj < RS_vk);
                `OP_XOR: CBD_value = RS_vj ^ RS_vk;
                `OP_SRL: CBD_value = RS_vj >> RS_vk[4:0];
                `OP_SRA: CBD_value = $signed(RS_vj) >>> RS_vk[4:0];
                `OP_OR: CBD_value = RS_vj | RS_vk;
                `OP_AND: CBD_value = RS_vj & RS_vk;
            endcase
        end
    end

endmodule

`endif