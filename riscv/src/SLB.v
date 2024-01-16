`include "utils.v"

`ifndef __SLB__
`define __SLB__

module SLB(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire pred_fail_flag,
    input wire[`ROB_SIZE_LOG - 1:0] rob_frontid,

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
    
    input wire ALU_valid,
    input wire[31:0] ALU_value,
    input wire[`ROB_SIZE_LOG - 1:0] ALU_robid,

    output reg mem_enable,
    output reg[2:0] mem_siz,
    output reg[31:0] mem_addr,
    output reg mem_wr_tag,  //store/load signal(1 for store)
    input wire mem_valid,
    output reg[31:0] mem_din,   //only valid when store
    input wire[31:0] mem_dout,  //only valid when load

    output reg CBD_enable,
    output reg[31:0] CBD_value,
    output reg[`ROB_SIZE_LOG - 1:0] CBD_ROBid,

    input wire rob_store_valid,
    input wire[`ROB_SIZE_LOG - 1:0] rob_store_valid_robid,
    output reg rob_store_enable,
    output reg[`ROB_SIZE_LOG - 1:0] rob_store_enable_robid,

    output wire SLB_next_full
);
    reg is_busy[`SLB_SIZE - 1:0];
    reg is_send_to_rob[`SLB_SIZE - 1:0];    //only used when store
    reg is_store_ready[`SLB_SIZE - 1:0];    //only used when store
    reg[`OP_SIZE_LOG - 1:0] op_type[`SLB_SIZE - 1:0];
    reg[31:0] vj[`SLB_SIZE - 1:0];
    reg[`ROB_SIZE_LOG - 1:0] qj[`SLB_SIZE - 1:0];
    reg rj[`SLB_SIZE - 1:0];
    reg[31:0] vk[`SLB_SIZE - 1:0];
    reg[`ROB_SIZE_LOG - 1:0] qk[`SLB_SIZE - 1:0];
    reg rk[`SLB_SIZE - 1:0];
    reg[31:0] imm[`SLB_SIZE - 1:0];
    reg[`ROB_SIZE_LOG - 1:0] dest_robid[`SLB_SIZE - 1:0];

    reg[`SLB_SIZE_LOG - 1:0] head, tail, back;
    wire is_empty = head == tail;
    wire[`ROB_SIZE_LOG - 1:0] front = (head + 1) & (`SLB_SIZE - 1);
    wire[31:0] front_addr = vj[front] + imm[front];
    wire[`SLB_SIZE_LOG - 1:0] nextid = (tail + 1) & (`SLB_SIZE - 1);

    reg is_waiting_mem;
    assign SLB_next_full = tail >= head ? tail - head + issue_valid - (rdy && is_waiting_mem && mem_valid) >= `SLB_SIZE - 1
    : tail + `SLB_SIZE - head + issue_valid - (rdy && is_waiting_mem && mem_valid) >= `SLB_SIZE - 1;

    integer i;
    always @(posedge clk) begin
        CBD_enable <= 0;
        rob_store_enable <= 0;
        if (rst || (pred_fail_flag && back == head)) begin  //防止被commit的store操作没有进行
            head <= 0;
            tail <= 0;
            back <= 0;
            is_waiting_mem <= 0;
            mem_enable <= 0;
            for (i = 0; i < `SLB_SIZE; i = i + 1) begin
                is_store_ready[i] <= 0;
                is_busy[i] <= 0;
                is_send_to_rob[i] <= 0;
                rj[i] <= 0;
                rk[i] <= 0;
            end
        end
        else if (!rdy) begin end
        else if (pred_fail_flag) begin  //做完该做的store操作
            tail <= back;
            for (i = 0; i < `SLB_SIZE; i = i + 1) begin
                if (!(is_busy[i] && is_store_ready[i])) begin
                    is_store_ready[i] <= 0;
                    is_busy[i] <= 0;
                    is_send_to_rob[i] <= 0;
                    rj[i] <= 0;
                    rk[i] <= 0;
                end
            end
            if (is_waiting_mem && mem_valid) begin
                is_waiting_mem <= 0;
                mem_enable <= 0;
                head <= (head + 1) & (`SLB_SIZE - 1);
                is_busy[front] <= 0;
                is_store_ready[front] <= 0;
                is_send_to_rob[front] <= 0;
                rj[front] <= 0;
                rk[front] <= 0;
            end
        end
        else begin
            if (issue_valid) begin
                is_busy[nextid] <= 1;
                is_store_ready[nextid] <= 0;
                is_send_to_rob[nextid] <= 0;
                op_type[nextid] <= issue_op_type;
                vj[nextid] <= issue_vj;
                qj[nextid] <= issue_qj;
                rj[nextid] <= issue_rj;
                vk[nextid] <= issue_vk;
                qk[nextid] <= issue_qk;
                rk[nextid] <= issue_op_type <= `OP_LHU ? 1 : issue_rk;
                imm[nextid] <= issue_imm;
                dest_robid[nextid] <= issue_robid;
                tail <= nextid;

                if (ALU_valid) begin
                    if(!issue_rj && issue_qj == ALU_robid) begin
                        rj[nextid] <= 1;
                        vj[nextid] <= ALU_value;
                    end
                    if(!issue_rk && issue_qk == ALU_robid) begin
                        rk[nextid] <= 1;
                        vk[nextid] <= ALU_value;
                    end
                end
                if (CBD_enable) begin
                    if(!issue_rj && issue_qj == CBD_ROBid) begin
                        rj[nextid] <= 1;
                        vj[nextid] <= CBD_value;
                    end
                    if(!issue_rk && issue_qk == CBD_ROBid) begin
                        rk[nextid] <= 1;
                        vk[nextid] <= CBD_value;
                    end
                end
            end
            if (ALU_valid) begin
                for (i = 0; i < `SLB_SIZE; i = i + 1) begin
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

            if (CBD_enable) begin
                for (i = 0; i < `SLB_SIZE; i = i + 1) begin
                    if (is_busy[i]) begin
                        if (!rj[i] && qj[i] == CBD_ROBid) begin
                            rj[i] <= 1;
                            vj[i] <= CBD_value;
                        end
                        if (!rk[i] && qk[i] == CBD_ROBid) begin
                            rk[i] <= 1;
                            vk[i] <= CBD_value;
                        end
                    end
                end
            end

            if (!is_empty && op_type[front] >= `OP_SB && rj[front] && rk[front] && !is_send_to_rob[front]) begin
                is_send_to_rob[front] <= 1;
                rob_store_enable <= 1;
                rob_store_enable_robid <= dest_robid[front];
            end

            if (rob_store_valid) begin 
                is_store_ready[front] <= 1;
                back <= front;
            end

            if (!is_waiting_mem) begin
                // if (!is_empty && rj[front] && rk[front] && 
                // !(op_type[front] <= `OP_LHU && front_addr[17:16] == 2'b11 && rob_frontid != dest_robid[front])) begin
                //     case(op_type[front]) 
                // end
                if (!is_empty && rj[front] && rk[front]) begin
                    if (op_type[front] <= `OP_LHU) begin
                        if (front_addr[17:16] != 2'b11 || rob_frontid == dest_robid[front]) begin
                            case(op_type[front])
                                `OP_LB, `OP_LBU: begin
                                    mem_enable <= 1;
                                    mem_siz <= 1;
                                    mem_addr <= front_addr;
                                    mem_wr_tag <= 0;
                                    is_waiting_mem <= 1;
                                end
                                `OP_LH, `OP_LHU: begin
                                    mem_enable <= 1;
                                    mem_siz <= 2;
                                    mem_addr <= front_addr;
                                    mem_wr_tag <= 0;
                                    is_waiting_mem <= 1;
                                end
                                `OP_LW: begin
                                    mem_enable <= 1;
                                    mem_siz <= 4;
                                    mem_addr <= front_addr;
                                    mem_wr_tag <= 0;
                                    is_waiting_mem <= 1;
                                end
                            endcase
                        end
                    end
                    else begin
                        if (is_store_ready[front]) begin
                            case(op_type[front])
                                `OP_SB: begin
                                    mem_enable <= 1;
                                    mem_siz <= 1;
                                    mem_addr <= front_addr;
                                    mem_wr_tag <= 1;
                                    is_waiting_mem <= 1;
                                    mem_din <= vk[front];
                                end
                                `OP_SH: begin
                                    mem_enable <= 1;
                                    mem_siz <= 2;
                                    mem_addr <= front_addr;
                                    mem_wr_tag <= 1;
                                    is_waiting_mem <= 1;
                                    mem_din <= vk[front];
                                end
                                `OP_SW: begin
                                    mem_enable <= 1;
                                    mem_siz <= 4;
                                    mem_addr <= front_addr;
                                    mem_wr_tag <= 1;
                                    is_waiting_mem <= 1;
                                    mem_din <= vk[front];
                                end
                            endcase
                        end
                    end
                end
            end
            else if (mem_valid) begin
                if (op_type[front] <= `OP_LHU && mem_enable) begin
                    CBD_enable <= 1;
                    CBD_ROBid <= dest_robid[front];
                    case (op_type[front])
                        `OP_LB: CBD_value <= {{24{mem_dout[7]}}, mem_dout[7:0]};
                        `OP_LH: CBD_value <= {{16{mem_dout[15]}}, mem_dout[15:0]};
                        `OP_LW: CBD_value <= mem_dout;
                        `OP_LBU: CBD_value <= {24'b0, mem_dout[7:0]};
                        `OP_LHU: CBD_value <= {16'b0, mem_dout[15:0]};
                    endcase
                end
                mem_enable <= 0;
                is_waiting_mem <= 0;
                head <= front;
                is_busy[front] <= 0;
                is_store_ready[front] <= 0;
                is_send_to_rob[front] <= 0;
                rj[front] <= 0;
                rk[front] <= 0;
                if (back == head) back <= front;
            end
        end
    end
endmodule

`endif