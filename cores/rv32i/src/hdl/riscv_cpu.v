`timescale 1ns / 1ps

`include "../include/rv32i_params.vh"
`include "../include/rv32i_control.vh"
`include "../include/axi_configuration.vh"


module riscv_cpu (
    input CLK,
    input RSTn,

    input pc_stall,

    // AXI4-lite connections to the memory
    output                         M_AXI_AWVALID,
    input                          M_AXI_AWREADY,
    output [  `AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output [                  2:0] M_AXI_AWPROT,
    output                         M_AXI_WVALID,
    input                          M_AXI_WREADY,
    output [  `AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output [`AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB,
    input                          M_AXI_BVALID,
    output                         M_AXI_BREADY,
    input  [                  1:0] M_AXI_BRESP,
    output                         M_AXI_ARVALID,
    input                          M_AXI_ARREADY,
    output [  `AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output [                  2:0] M_AXI_ARPROT,
    input                          M_AXI_RVALID,
    output                         M_AXI_RREADY,
    input  [  `AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  [                  1:0] M_AXI_RRESP
);

    reg  [      `DATA_WIDTH-1:0] pc;
    wire [      `DATA_WIDTH-1:0] pc_next;
    wire [      `DATA_WIDTH-1:0] pc_plus_4;
    wire                         pc_select;
    reg                          pc_valid;

    // Fetch output
    // MEMORY ARBITER WIRES
    wire [      `DATA_WIDTH-1:0] instruction;
    wire                         instruction_valid;
    // load/store
    reg  [      `DATA_WIDTH-1:0] mem_read_write_addr;
    reg  [      `DATA_WIDTH-1:0] mem_write_data;
    reg  [      `DATA_WIDTH-1:0] mem_read_data;
    reg                          mem_read_enable;
    reg                          mem_write_enable;
    reg  [`AXI_STROBE_WIDTH-1:0] mem_write_strobe;
    wire                         mem_read_write_valid;

    // Decode output
    wire                         is_jump;
    wire                         is_jalr;
    wire                         is_branch;
    wire [      `DATA_WIDTH-1:0] immediate;
    wire [     `FUNC3_WIDTH-1:0] func3;
    wire [  `REG_ADDR_WIDTH-1:0] rs1_addr;
    wire [  `REG_ADDR_WIDTH-1:0] rs2_addr;
    wire [  `REG_ADDR_WIDTH-1:0] rd_addr;
    wire                         alu_src1_is_pc;
    wire                         alu_src2_is_imm;
    wire                         use_mem;
    wire                         mem_write;
    wire                         do_write_back;
    wire [  `ALU_CTRL_WIDTH-1:0] alu_ctrl;

    wire [      `DATA_WIDTH-1:0] rs1;
    wire [      `DATA_WIDTH-1:0] rs2;

    // ALU output
    wire [      `DATA_WIDTH-1:0] alu_result;
    reg                          alu_result_valid;
    wire                         take_branch;

    wire [      `DATA_WIDTH-1:0] mem_wb_data;
    wire                         mem_valid;

    reg  [      `DATA_WIDTH-1:0] write_back_data;
    reg                          write_back_data_valid;

    reg                          instruction_done;

    // =====   Clocked Components    =====

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            // init pc one step below so that when we can start the cpu by incrementing the pc
            pc <= `BOOT_ADDR - `PC_STEP;
            pc_valid <= 1'b0;
        end else if (!pc_stall && instruction_done) begin
            pc <= pc_next;
            pc_valid <= 1'b1;
        end else begin
            pc_valid <= 1'b0;
        end
    end

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            alu_result_valid <= 1'b0;
        end else begin
            alu_result_valid <= instruction_valid && alu_ctrl != `ALU_CTRL_NOP;
        end
    end

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            instruction_done <= 1'b1;
        end else if (!pc_stall) begin
            instruction_done <= write_back_data_valid;
        end
    end

    register_file u_register_file (
        .clk(CLK),
        .rst(!RSTn),

        .read_enable (1'b1),
        .rs1_addr    (rs1_addr),
        .rs2_addr    (rs2_addr),
        .rs1         (rs1),
        .rs2         (rs2),
        .write_enable(do_write_back & write_back_data_valid),
        .write_addr  (rd_addr),
        .write_data  (write_back_data)
    );

    memory_arbiter u_memory_arbiter (
        .CLK (CLK),
        .RSTn(RSTn),

        .M_AXI_AWVALID(M_AXI_AWVALID),
        .M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_AWADDR (M_AXI_AWADDR),
        .M_AXI_AWPROT (M_AXI_AWPROT),
        .M_AXI_WVALID (M_AXI_WVALID),
        .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),
        .M_AXI_WSTRB  (M_AXI_WSTRB),
        .M_AXI_BVALID (M_AXI_BVALID),
        .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_BRESP  (M_AXI_BRESP),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_ARADDR (M_AXI_ARADDR),
        .M_AXI_ARPROT (M_AXI_ARPROT),
        .M_AXI_RVALID (M_AXI_RVALID),
        .M_AXI_RREADY (M_AXI_RREADY),
        .M_AXI_RDATA  (M_AXI_RDATA),
        .M_AXI_RRESP  (M_AXI_RRESP),

        .pc               (pc),
        .pc_valid         (pc_valid),
        .instruction      (instruction),
        .instruction_valid(instruction_valid),

        .read_write_addr (mem_read_write_addr),
        .write_data      (mem_write_data),
        .read_data       (mem_read_data),
        .read_enable     (mem_read_enable),
        .write_enable    (mem_write_enable),
        .write_strobe    (mem_write_strobe),
        .read_write_valid(mem_read_write_valid)
    );


    // =====   Clocked Components    =====
    // =====   Fetch stage   =====

    assign pc_plus_4 = pc + 32'd4;
    assign pc_select = is_jump | (is_branch & take_branch);
    assign pc_next   = pc_select ? (is_jalr ? rs1 : pc) + immediate : pc_plus_4;

    // =====   Fetch stage    =====
    // =====   Decode stage   =====

    instruction_decode u_decode (
        .instr          (instruction),
        .func3          (func3),
        .rs1_addr       (rs1_addr),
        .rs2_addr       (rs2_addr),
        .rd_addr        (rd_addr),
        .imm            (immediate),
        .alu_src1_is_pc (alu_src1_is_pc),
        .alu_src2_is_imm(alu_src2_is_imm),
        .use_mem        (use_mem),
        .mem_write      (mem_write),
        .is_branch      (is_branch),
        .is_jump        (is_jump),
        .is_jalr        (is_jalr),
        .do_write_back  (do_write_back),
        .alu_ctrl       (alu_ctrl)
    );

    // =====   Decode stage   =====
    // =====   Execute stage   =====

    alu u_alu (
        .alu_ctrl   (alu_ctrl),
        .src1       (alu_src1_is_pc ? pc : rs1),
        .src2       (alu_src2_is_imm ? immediate : rs2),
        .result     (alu_result),
        .take_branch(take_branch)
    );

    load_store_decoder u_load_store_decoder (
        .alu_result_addr(alu_result),
        .func3          (func3),
        .reg_read       (rs2),
        .byte_enb       (mem_write_strobe),
        .data           (mem_write_data)
    );

    // =====   Execute stage   =====
    // =====   Memory stage   =====

    // data RAM wiring
    // assign d_w_addr     = {alu_result[`RAM_ADDR_WIDTH-1:2], 2'b00};
    // assign d_w_dat      = mem_write_data;
    // assign d_w_enb      = use_mem & mem_write;
    // assign d_w_byte_enb = byte_enb;  // from load store decoder
    // assign d_r_addr     = alu_result[`RAM_ADDR_WIDTH-1:0];
    // assign d_r_enb      = use_mem & !mem_write;
    // 

    assign mem_read_write_addr = mem_write ? {alu_result[`DATA_WIDTH-1:2], 2'b00}: alu_result[`DATA_WIDTH-1:0];
    assign mem_read_enable = use_mem & !mem_write;
    assign mem_write_enable = use_mem & mem_write;

    byte_reader u_byte_reader (
        .mem_data (mem_read_data),
        .func3    (func3),
        .byte_mask(mem_write_strobe),
        .wb_data  (mem_wb_data),
        .valid    (mem_valid)
    );
    // =====   Memory stage   =====
    // =====   Write back stage   =====

    always @(*)
        if (is_jump) begin
            write_back_data = pc_plus_4;
            write_back_data_valid = instruction_valid;
        end else if (use_mem) begin
            write_back_data = mem_wb_data;
            write_back_data_valid = mem_read_write_valid;
        end else begin
            write_back_data = alu_result;
            write_back_data_valid = alu_result_valid;
        end

    // =====   Write back stage   =====

endmodule
