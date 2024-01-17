`include "utils.v"

`ifndef __MEMCTRL__
`define __MEMCTRL__

module mem_ctrl (
    input wire clk,
    input wire rst,
    input wire rdy,

    input  wire [ 7:0]          mem_din,		// data input bus
    output reg [ 7:0]          mem_dout,		// data output bus
    output reg [31:0]          mem_a,			// address bus (only 17:0 is used)
    output reg                 mem_wr,			// write/read signal (1 for write)
    input  wire                 io_buffer_full, // 1 if uart buffer is full

    input wire ic_valid,
    input wire[31:0] addr_from_ic,
    output reg ic_enable,
    output reg[31:0] inst_to_ic,

    input wire slb_valid,
    input wire slb_wr,      //store/load signal(1 for store)
    input wire[31:0] addr_from_slb,
    input wire[2:0] siz_from_slb,   //1 or 2 or 4
    input wire[31:0] slb_din,   //only valid when store
    output reg[31:0] slb_dout,  //only valid when load
    output reg slb_enable
);

    reg[2:0] pos;   //one byte read/write only in one cycle
    reg[1:0] status;   //0 for null, 1 for instruction read, 2 for store, 3 for load
    always @(posedge clk) begin
        if (rst) begin
            mem_wr <= 0;
            ic_enable <= 0;
            slb_enable <= 0;
            pos <= 0;
            status <= 0;
        end
        else if (!rdy) begin
            mem_wr <= 0;
            ic_enable <= 0;
            slb_enable <= 0;
            mem_a <= 0;
        end
        else begin
            mem_wr <= 0;
            case (status)
                0: begin
                    ic_enable <= 0;
                    slb_enable <= 0;
                    if (!ic_enable && !slb_enable) begin    //wait a cycle,don't know why need do this
                        if (slb_valid) begin
                            if (slb_wr) begin   //store
                                //mem_wr <= 0;    //do not store immediately
                                status <= 2;
                                mem_a <= 0;
                            end else begin    //load
                                //mem_wr <= 0;
                                status <= 3;
                                mem_a <= addr_from_slb;
                            end
                            pos <= 0;
                        end
                        else if (ic_valid) begin
                            //mem_wr <= 0;
                            mem_a <= addr_from_ic;
                            status <= 1;
                            pos <= 0;
                        end
                    end
                end
                1: //ins read
                if (ic_valid) begin    
                    case(pos)   //todo: why start from 1
                        3'd1: inst_to_ic[7:0] <= mem_din;
                        3'd2: inst_to_ic[15:8] <= mem_din;
                        3'd3: inst_to_ic[23:16] <= mem_din;
                        3'd4: inst_to_ic[31:24] <= mem_din;
                    endcase
                    if (pos == 3'd4) begin
                        status <= 0;
                        ic_enable <= 1;
                    end
                    else begin
                        mem_a <= mem_a + 1;
                        pos <= pos + 1;
                    end
                end else status <= 0;
                2: 
                //if (!io_buffer_full || addr_from_slb[17:16] != 2'b11) begin
                //if (addr_from_slb[17:16] != 2'b11) 
                begin
                    mem_wr <= 1;
                    case (pos) 
                        3'd0: mem_dout <= slb_din[7:0];
                        3'd1: mem_dout <= slb_din[15:8];
                        3'd2: mem_dout <= slb_din[23:16];
                        3'd3: mem_dout <= slb_din[31:24];
                    endcase
                    if (pos == siz_from_slb) begin
                        mem_wr <= 0;
                        mem_a <= 0;
                        status <= 0;
                        slb_enable <= 1;
                    end
                    else begin
                        if (pos == 0) mem_a <= addr_from_slb;
                        else mem_a <= mem_a + 1;
                        pos <= pos + 1;
                    end
                end

                3:   //load
                if (slb_valid) begin
                    case(pos) 
                        3'd1: slb_dout[7:0] <= mem_din;
                        3'd2: slb_dout[15:8] <= mem_din;
                        3'd3: slb_dout[23:16] <= mem_din;
                        3'd4: slb_dout[31:24] <= mem_din;
                    endcase
                    if (pos == siz_from_slb) begin
                        status <= 0;
                        slb_enable <= 1;
                    end
                    else begin
                        mem_a <= mem_a + 1;
                        pos <= pos + 1;
                    end
                end
                else status <= 0;
            endcase
        end
    end

endmodule

`endif