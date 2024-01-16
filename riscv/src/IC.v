`ifndef __ICACHE__
`define __ICACHE__

module ICache (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire[31:0] pc_from_if,

    output wire inst_enable,
    output wire[31:0] inst_to_if,

    output reg memc_enable,
    output reg[31:0] addr_to_memc,

    input wire memc_valid,
    input wire[31:0] inst_from_memc 
);
    reg is_busy;
    reg vis[255:0];
    reg[17:10] tag[255:0];
    reg[31:0] data[255:0];  //exactly a hash

    wire hit = vis[pc_from_if[9:2]] && tag[pc_from_if[9:2]] == pc_from_if[17:10];
    assign inst_enable = hit || (memc_valid && pc_from_if == addr_to_memc);
    assign inst_to_if = hit ? data[pc_from_if[9:2]] : inst_from_memc;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            is_busy <= 0;
            memc_enable <= 0;
            for (i = 0; i < 256; i = i + 1)
                vis[i] <= 0;
        end
        else if (!rdy) begin end
        else begin 
            if (is_busy) begin
                if (memc_valid) begin
                    vis[addr_to_memc[9:2]] <= 1;
                    tag[addr_to_memc[9:2]] <= addr_to_memc[17:10];
                    data[addr_to_memc[9:2]] <= inst_from_memc;
                    memc_enable <= 0;
                    is_busy <= 0;
                end
            end
            else if (!hit) begin
                is_busy <= 0;
                memc_enable <= 1;
                addr_to_memc <= pc_from_if;
            end
        end
    end
endmodule

`endif