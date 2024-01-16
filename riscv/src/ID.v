`include "utils.v"

`ifndef __INST_DECODE__
`define __INST_DECODE__

module InstDecode (
    input wire [31:0] inst,

    output reg [5:0] op_type,
    output reg [4:0] rs1,
    output reg [4:0] rs2,
    output reg [4:0] rd,
    output reg [31:0] imm
);
    wire [6:0] typeId = inst[6:0];
    wire [2:0] detail_type1 = inst[14:12];
    wire [6:0] detail_type2 = inst[31:25];
    always @(*) begin
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        rd = inst[11:7];
        case (typeId)
            7'b0110111: begin
               imm = inst[31:12] << 12;
               op_type = `OP_LUI;
            end
            7'b0010111: begin
                imm = inst[31:12] << 12;
                op_type = `OP_AUIPC;
            end
            7'b1101111: begin
                imm = { {12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0 };
                op_type = `OP_JAL;
            end
            7'b1100111: begin
                imm = { {21{inst[31]}}, inst[30:20] };
                op_type = `OP_JALR;
            end
            7'b0000011: begin
                imm = { {21{inst[31]}}, inst[30:20] };
                case (detail_type1)
                    3'b000: op_type = `OP_LB;
                    3'b001: op_type = `OP_LH;
                    3'b010: op_type = `OP_LW;
                    3'b100: op_type = `OP_LBU;
                    3'b101: op_type = `OP_LHU;
                endcase
            end
            7'b0010011: begin
                imm = { {21{inst[31]}}, inst[30:20] };
                case (detail_type1)
                    3'b001: op_type = `OP_SLLI;
                    3'b101: begin
                        case(detail_type2) 
                            7'b0000000: op_type = `OP_SRLI;
                            7'b0100000: op_type = `OP_SRAI;
                        endcase
                    end
                    3'b000: op_type = `OP_ADDI;
                    3'b010: op_type = `OP_SLTI;
                    3'b011: op_type = `OP_SLTIU;
                    3'b100: op_type = `OP_XORI;
                    3'b110: op_type = `OP_ORI;
                    3'b111: op_type = `OP_ANDI;
                endcase
            end
            7'b1100011: begin
                imm = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };
                case (detail_type1) 
                    3'b000: op_type = `OP_BEQ;
                    3'b001: op_type = `OP_BNE;
                    3'b100: op_type = `OP_BLT;
                    3'b101: op_type = `OP_BGE;
                    3'b110: op_type = `OP_BLTU;
                    3'b111: op_type = `OP_BGEU;
                endcase
            end
            7'b0100011: begin
                imm = { {21{inst[31]}}, inst[30:25], inst[11:7] };
                case (detail_type1)
                    3'b000: op_type = `OP_SB;
                    3'b001: op_type = `OP_SH;
                    3'b010: op_type = `OP_SW;
                endcase
            end
            7'b0110011: begin
                case (detail_type2)
                    7'b0100000: begin
                        case (detail_type1)
                            3'b000: op_type = `OP_SUB;
                            3'b101: op_type = `OP_SRA;
                        endcase
                    end
                    7'b0000000: begin
                        case (detail_type1)
                            3'b000: op_type = `OP_ADD;
                            3'b001: op_type = `OP_SLL;
                            3'b010: op_type = `OP_SLT;
                            3'b011: op_type = `OP_SLTU;
                            3'b100: op_type = `OP_XOR;
                            3'b101: op_type = `OP_SRL;
                            3'b110: op_type = `OP_OR;
                            3'b111: op_type = `OP_AND;
                        endcase 
                    end
                endcase
            end

        endcase
    end

endmodule

`endif