`timescale 1ns / 1ps

`include "../include/axi_configuration.vh"
`include "../include/rv32i_params.vh"

`define STATE_WIDTH 3
`define STATE_IDLE 3'd0
`define STATE_PC_ADDR 3'd1
`define STATE_PC_DATA 3'd2
`define STATE_PC_3 3'd3

module memory_arbiter (
    input wire CLK,
    input wire RSTn,

    // AXI4-lite connections
    output reg                            M_AXI_AWVALID,
    input  wire                           M_AXI_AWREADY,
    output reg  [  `C_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output reg  [                    2:0] M_AXI_AWPROT,
    output reg                            M_AXI_WVALID,
    input  wire                           M_AXI_WREADY,
    output reg  [  `C_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output reg  [`C_AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB,
    input  wire                           M_AXI_BVALID,
    output reg                            M_AXI_BREADY,
    input  wire [                    1:0] M_AXI_BRESP,
    output reg                            M_AXI_ARVALID,
    input  wire                           M_AXI_ARREADY,
    output reg  [  `C_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output reg  [                    2:0] M_AXI_ARPROT,
    input  wire                           M_AXI_RVALID,
    output reg                            M_AXI_RREADY,
    input  wire [  `C_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                    1:0] M_AXI_RRESP,

    // instruction fetching
    input  wire [ `DATA_WIDTH-1:0] pc,
    input  wire                    pc_valid,
    output reg  [`INSTR_WIDTH-1:0] instruction,
    output reg                     instruction_valid,

    // load/store
    input  wire [        `DATA_WIDTH-1:0] addr,
    input  wire [        `DATA_WIDTH-1:0] write_data,
    input  wire [        `DATA_WIDTH-1:0] read_data,
    input  wire                           read_enable,
    input  wire                           write_enable,
    input  wire [`C_AXI_STROBE_WIDTH-1:0] write_strobe,
    output reg                            operation_valid
);

    reg [`STATE_WIDTH-1:0] state;
    reg [ `DATA_WIDTH-1:0] pc_latched;

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            state <= `STATE_IDLE;
            pc_latched <= 0;
            instruction <= 0;
            instruction_valid <= 0;
        end else begin
            if (state == `STATE_IDLE && pc_valid) begin
                state <= `STATE_PC_ADDR;
                pc_latched <= pc;
            end else if (state == `STATE_PC_ADDR && M_AXI_ARREADY) begin
                // read address transaction
                state <= `STATE_PC_DATA;
            end else if (state == `STATE_PC_DATA && M_AXI_RVALID) begin
                // read data transaction
                state <= `STATE_IDLE;
                instruction <= M_AXI_RDATA;
                instruction_valid <= 1;
            end
        end
    end

    always @(*) begin
        if (state == `STATE_PC_ADDR) begin
            M_AXI_ARVALID <= 1;
            M_AXI_ARADDR  <= pc_latched;
        end else begin
            M_AXI_ARVALID <= 0;
            M_AXI_ARADDR  <= 0;
        end
    end

    always @(*) begin
        if (state == `STATE_PC_DATA) begin
            M_AXI_RREADY <= 1;
        end else begin
            M_AXI_RREADY <= 0;
        end
    end

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            M_AXI_AWVALID <= 0;
            M_AXI_AWADDR  <= 0;
            M_AXI_AWPROT  <= 0;
            M_AXI_WVALID  <= 0;
            M_AXI_WDATA   <= 0;
            M_AXI_WSTRB   <= 0;
            M_AXI_BREADY  <= 0;
            M_AXI_ARPROT  <= 0;
        end else begin
        end
    end

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            operation_valid <= 0;
        end else begin
        end
    end

endmodule
