// RISCV32I CPU top module
// port modification allowed for debugging purposes

`include "ALU.v"
`include "IC.v"
`include "IF.v"
`include "issue.v"
`include "mem_ctrl.v"
`include "RegFile.v"
`include "ROB.v"
`include "RS.v"
`include "SLB.v"
`include "utils.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)
  wire pred_fail_flag;
  wire[31:0] right_target_pc;
  wire[`ROB_SIZE_LOG - 1:0] next_robid;
  wire[`ROB_SIZE_LOG - 1:0] rob_frontid;
  
  wire rs_to_alu_valid;
  wire[5:0] rs_to_alu_op_type;
  wire[31:0] rs_to_alu_vj;
  wire[31:0] rs_to_alu_vk;
  wire[31:0] rs_to_alu_imm;
  wire[`ROB_SIZE_LOG - 1:0] rs_to_alu_robid;
  wire[31:0] rs_to_alu_curpc;
  wire alu_CBD_enable;
  wire[31:0] alu_CBD_value;
  wire[`ROB_SIZE_LOG - 1:0] alu_CBD_robid;
  wire[31:0] alu_CBD_topc;

  alu riscv_alu(
    .rst(rst_in),
    .rdy(rdy_in),
    .RS_valid(rs_to_alu_valid),
    .RS_op(rs_to_alu_op_type),
    .RS_vj(rs_to_alu_vj),
    .RS_vk(rs_to_alu_vk),
    .RS_imm(rs_to_alu_imm),
    .RS_ROBid(rs_to_alu_robid),
    .RS_curpc(rs_to_alu_curpc),
    .CBD_enable(alu_CBD_enable),
    .CBD_value(alu_CBD_value),
    .CBD_ROBid(alu_CBD_robid),
    .CBD_topc(alu_CBD_topc)
  );

  wire[31:0] if_to_ic_pc;
  wire ic_to_if_inst_enable;
  wire[31:0] ic_to_if_inst;
  wire ic_to_mc_enable;
  wire[31:0] ic_to_mc_addr;
  wire mc_to_ic_enable;
  wire[31:0] mc_to_ic_inst;

  ICache riscv_icache(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .pc_from_if(if_to_ic_pc),
    .inst_enable(ic_to_if_inst_enable),
    .inst_to_if(ic_to_if_inst),
    .memc_enable(ic_to_mc_enable),
    .addr_to_memc(ic_to_mc_addr),
    .memc_valid(mc_to_ic_enable),
    .inst_from_memc(mc_to_ic_inst)
  );

  wire if_to_issue_inst_valid;
  wire[31:0] issue_pc;
  wire issue_pred;
  wire[`OP_SIZE_LOG - 1:0] issue_op_type;
  wire[4:0] issue_rd;
  wire[31:0] issue_imm;
  wire[4:0] issue_rs1;
  wire[4:0] issue_rs2;
  wire rob_next_full;
  wire rs_next_full;
  wire slb_next_full;
  wire upd_prd_valid;
  wire[9:2] upd_prd_index;
  wire upd_prd_isjump;
  
  IFetch riscv_if(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .pc_to_ic(if_to_ic_pc),
    .inst_valid(ic_to_if_inst_enable),
    .inst_from_ic(ic_to_if_inst),
    .inst_send_enable(if_to_issue_inst_valid),
    .pc_to_issue(issue_pc),
    .pred_to_issue(issue_pred),
    .op_type_to_issue(issue_op_type),
    .rd_to_issue(issue_rd),
    .imm_to_issue(issue_imm),
    .rs1_to_RF(issue_rs1),
    .rs2_to_RF(issue_rs2),
    .jump_flag(pred_fail_flag),
    .target_pc(right_target_pc),
    .ROB_full(rob_next_full),
    .RS_full(rs_next_full),
    .SLB_full(slb_next_full),
    .upd_prd_valid(upd_prd_valid),
    .upd_prd_index(upd_prd_index),
    .upd_prd_isjump(upd_prd_isjump)
  );

  wire[31:0] rf_to_issue_vj;
  wire[31:0] rf_to_issue_vk;
  wire[`ROB_SIZE_LOG - 1:0] rf_to_issue_qj;
  wire[`ROB_SIZE_LOG - 1:0] rf_to_issue_qk;
  wire rf_to_issue_rj;
  wire rf_to_issue_rk;
  wire rob_to_issue_rs1_ready;
  wire[31:0] rob_to_issue_rs1_value;
  wire rob_to_issue_rs2_ready;
  wire[31:0] rob_to_issue_rs2_value;
  wire issue_to_rob_valid;
  wire[`ROB_SIZE_LOG - 1:0] issue_send_robid;
  wire issue_to_rf_valid;
  wire issue_to_rs_valid;
  wire issue_to_slb_valid;
  wire[31:0] issue_vj;
  wire[31:0] issue_vk;
  wire[`ROB_SIZE_LOG - 1:0] issue_qj;
  wire[`ROB_SIZE_LOG - 1:0] issue_qk;
  wire issue_rj;
  wire issue_rk;
  issue riscv_issue(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .inst_valid(if_to_issue_inst_valid),
    .op_type(issue_op_type),
    .vj_from_rf(rf_to_issue_vj),
    .qj_from_rf(rf_to_issue_qj),
    .rj_from_rf(rf_to_issue_rj),
    .vk_from_rf(rf_to_issue_vk),
    .qk_from_rf(rf_to_issue_qk),
    .rk_from_rf(rf_to_issue_rk),
    .rob_rs1_ready(rob_to_issue_rs1_ready),
    .rob_rs1_value(rob_to_issue_rs1_value),
    .rob_rs2_ready(rob_to_issue_rs2_ready),
    .rob_rs2_value(rob_to_issue_rs2_value),
    .next_robid(next_robid),
    .rob_send_enable(issue_to_rob_valid),
    .send_robid(issue_send_robid),
    .rf_send_enable(issue_to_rf_valid),
    .rs_send_enable(issue_to_rs_valid),
    .slb_send_enable(issue_to_slb_valid),
    .vj(issue_vj),
    .qj(issue_qj),
    .rj(issue_rj),
    .vk(issue_vk),
    .qk(issue_qk),
    .rk(issue_rk)
  );

  wire slb_to_memc_valid;
  wire slb_to_memc_wr;
  wire[31:0] slb_to_memc_addr;
  wire[2:0] slb_to_memc_size;
  wire[31:0] slb_din;
  wire[31:0] slb_dout;
  wire memc_to_slb_valid;

  mem_ctrl riscv_memctrl(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .mem_din(mem_din),
    .mem_dout(mem_dout),
    .mem_a(mem_a),
    .mem_wr(mem_wr),
    .io_buffer_full(io_buffer_full),
    .ic_valid(ic_to_mc_enable),
    .addr_from_ic(ic_to_mc_addr),
    .ic_enable(mc_to_ic_enable),
    .inst_to_ic(mc_to_ic_inst),
    .slb_valid(slb_to_memc_valid),
    .slb_wr(slb_to_memc_wr),
    .addr_from_slb(slb_to_memc_addr),
    .siz_from_slb(slb_to_memc_size),
    .slb_din(slb_din),
    .slb_dout(slb_dout),
    .slb_enable(memc_to_slb_valid)
  );

  wire commit_valid;
  wire[4:0] commit_regid;
  wire[31:0] commit_value;
  wire[`ROB_SIZE_LOG - 1:0] commit_robid;
  reg_file riscv_regfile(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rs1(issue_rs1),
    .rs2(issue_rs2),
    .vj(rf_to_issue_vj),
    .qj(rf_to_issue_qj),
    .rj(rf_to_issue_rj),
    .vk(rf_to_issue_vk),
    .qk(rf_to_issue_qk),
    .rk(rf_to_issue_rk),
    .commit_valid(commit_valid),
    .commit_regid(commit_regid),
    .commit_value(commit_value),
    .commit_robid(commit_robid),
    .rename_valid(issue_to_rf_valid),
    .rename_regid(issue_rd),
    .rename_robid(issue_send_robid),
    .pred_fail_flag(pred_fail_flag)
  );

  wire slb_CBD_enable;
  wire[31:0] slb_CBD_value;
  wire[`ROB_SIZE_LOG - 1:0] slb_CBD_robid;
  wire rob_to_slb_valid;
  wire[`ROB_SIZE_LOG - 1:0] rob_to_slb_robid;
  wire slb_to_rob_valid;
  wire[`ROB_SIZE_LOG - 1:0] slb_to_rob_robid;
  SLB riscv_slb(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .pred_fail_flag(pred_fail_flag),
    .rob_frontid(rob_frontid),
    .issue_valid(issue_to_slb_valid),
    .issue_op_type(issue_op_type),
    .issue_vj(issue_vj),
    .issue_qj(issue_qj),
    .issue_rj(issue_rj),
    .issue_vk(issue_vk),
    .issue_qk(issue_qk),
    .issue_rk(issue_rk),
    .issue_imm(issue_imm),
    .issue_robid(issue_send_robid),
    .ALU_valid(alu_CBD_enable),
    .ALU_value(alu_CBD_value),
    .ALU_robid(alu_CBD_robid),
    .mem_enable(slb_to_memc_valid),
    .mem_siz(slb_to_memc_size),
    .mem_addr(slb_to_memc_addr),
    .mem_wr_tag(slb_to_memc_wr),
    .mem_valid(memc_to_slb_valid),
    .mem_din(slb_din),
    .mem_dout(slb_dout),
    .CBD_enable(slb_CBD_enable),
    .CBD_value(slb_CBD_value),
    .CBD_ROBid(slb_CBD_robid),
    .rob_store_valid(rob_to_slb_valid),
    .rob_store_valid_robid(rob_to_slb_robid),
    .rob_store_enable(slb_to_rob_valid),
    .rob_store_enable_robid(slb_to_rob_robid),
    .SLB_next_full(slb_next_full)
  );

  ROB riscv_rob(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .issue_valid(issue_to_rob_valid),
    .issue_op_type(issue_op_type),
    .issue_dest(issue_rd),
    .issue_pc(issue_pc),
    .issue_pred(issue_pred),
    .ALU_valid(alu_CBD_enable),
    .ALU_value(alu_CBD_value),
    .ALU_robid(alu_CBD_robid),
    .ALU_topc(alu_CBD_topc),
    .SLB_load_valid(slb_CBD_enable),
    .SLB_load_value(slb_CBD_value),
    .SLB_load_robid(slb_CBD_robid),
    .SLB_store_valid(slb_to_rob_valid),
    .SLB_store_robid(slb_to_rob_robid),
    .commit_enable(commit_valid),
    .commit_regid(commit_regid),
    .commit_value(commit_value),
    .commit_robid(commit_robid),
    .pred_fail_flag(pred_fail_flag),
    .toPc_to_if(right_target_pc),
    .upd_prd_enable(upd_prd_valid),
    .upd_prd_index(upd_prd_index),
    .upd_prd_isjump(upd_prd_isjump),
    .slb_store_enable(rob_to_slb_valid),
    .slb_store_begin_robid(rob_to_slb_robid),
    .rs1_query_from_issue(rf_to_issue_qj),
    .rs2_query_from_issue(rf_to_issue_qk),
    .rs1_ready(rob_to_issue_rs1_ready),
    .rs1_value(rob_to_issue_rs1_value),
    .rs2_ready(rob_to_issue_rs2_ready),
    .rs2_value(rob_to_issue_rs2_value),
    .rob_next_full(rob_next_full),
    .rob_nextid(next_robid),
    .rob_frontid(rob_frontid)
  );

  RS riscv_rs(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .issue_valid(issue_to_rs_valid),
    .issue_op_type(issue_op_type),
    .issue_vj(issue_vj),
    .issue_qj(issue_qj),
    .issue_rj(issue_rj),
    .issue_vk(issue_vk),
    .issue_qk(issue_qk),
    .issue_rk(issue_rk),
    .issue_imm(issue_imm),
    .issue_robid(issue_send_robid),
    .issue_curPc(issue_pc),
    .ALU_valid(alu_CBD_enable),
    .ALU_value(alu_CBD_value),
    .ALU_robid(alu_CBD_robid),
    .SLB_load_valid(slb_CBD_enable),
    .SLB_load_value(slb_CBD_value),
    .SLB_load_robid(slb_CBD_robid),
    .ALU_enable(rs_to_alu_valid),
    .op_to_ALU(rs_to_alu_op_type),
    .vj_to_ALU(rs_to_alu_vj),
    .vk_to_ALU(rs_to_alu_vk),
    .imm_to_ALU(rs_to_alu_imm),
    .robid_to_ALU(rs_to_alu_robid),
    .curpc_to_ALU(rs_to_alu_curpc),
    .pred_fail_flag(pred_fail_flag),
    .RS_next_full(rs_next_full)
  );
  
  
endmodule