`timescale 1ns / 1ps

`include "../include/axi_configuration.vh"
`include "../include/rv32i_params.vh"

`define STATE_WIDTH 4
`define STATE_IDLE `STATE_WIDTH'd0
`define STATE_PC_WAIT_ARREADY `STATE_WIDTH'd1
`define STATE_PC_DATA `STATE_WIDTH'd2
`define STATE_L_WAIT_ARREADY `STATE_WIDTH'd3
`define STATE_L_DATA `STATE_WIDTH'd4
`define STATE_S_WAIT_BOTH `STATE_WIDTH'd5
`define STATE_S_WAIT_AWREADY `STATE_WIDTH'd6
`define STATE_S_WAIT_WREADY `STATE_WIDTH'd7
`define STATE_S_RESP `STATE_WIDTH'd8

module memory_arbiter (
    input CLK,
    input RSTn,

    // AXI4-lite connections
    output reg                         M_AXI_AWVALID,
    input                              M_AXI_AWREADY,
    output reg [  `AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output reg [                  2:0] M_AXI_AWPROT,
    output reg                         M_AXI_WVALID,
    input                              M_AXI_WREADY,
    output reg [  `AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output reg [`AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB,
    input                              M_AXI_BVALID,
    output reg                         M_AXI_BREADY,
    input      [                  1:0] M_AXI_BRESP,
    output reg                         M_AXI_ARVALID,
    input                              M_AXI_ARREADY,
    output reg [  `AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output reg [                  2:0] M_AXI_ARPROT,
    input                              M_AXI_RVALID,
    output reg                         M_AXI_RREADY,
    input      [  `AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input      [                  1:0] M_AXI_RRESP,

    // instruction fetching
    input      [ `DATA_WIDTH-1:0] pc,
    input                         pc_valid,
    output reg [`INSTR_WIDTH-1:0] instruction,
    output reg                    instruction_valid,

    // load/store
    input      [      `DATA_WIDTH-1:0] read_write_addr,
    input                              read_enable,
    output reg [      `DATA_WIDTH-1:0] read_data,
    input                              write_enable,
    input      [      `DATA_WIDTH-1:0] write_data,
    input      [`AXI_STROBE_WIDTH-1:0] write_strobe,
    output reg                         read_write_valid
);

    reg [`STATE_WIDTH-1:0] state;
    reg [`STATE_WIDTH-1:0] next_state;
    reg [ `DATA_WIDTH-1:0] pc_latched;

    // state machine
    always @(*) begin
        next_state = state;
        case (state)
            `STATE_IDLE:
            // Skip address phase, if the slave was ready to receive the address
            if (pc_valid) begin
                if (M_AXI_ARREADY) next_state = `STATE_PC_DATA;
                else next_state = `STATE_PC_WAIT_ARREADY;
            end else if (read_enable) begin
                if (M_AXI_ARREADY) next_state = `STATE_L_DATA;
                else next_state = `STATE_L_WAIT_ARREADY;
            end else if (write_enable) begin
                if (M_AXI_AWREADY & M_AXI_WREADY) next_state = `STATE_S_RESP;
                else if (M_AXI_AWREADY) next_state = `STATE_S_WAIT_WREADY;
                else if (M_AXI_WREADY) next_state = `STATE_S_WAIT_AWREADY;
                else next_state = `STATE_S_WAIT_BOTH;
            end
            `STATE_PC_WAIT_ARREADY: if (M_AXI_ARREADY) next_state = `STATE_PC_DATA;
            `STATE_L_WAIT_ARREADY: if (M_AXI_ARREADY) next_state = `STATE_L_DATA;
            `STATE_S_WAIT_BOTH: begin
                if (M_AXI_AWREADY & M_AXI_WREADY) next_state = `STATE_S_RESP;
                else if (M_AXI_AWREADY) next_state = `STATE_S_WAIT_WREADY;
                else if (M_AXI_WREADY) next_state = `STATE_S_WAIT_AWREADY;
            end
            `STATE_S_WAIT_AWREADY: if (M_AXI_AWREADY) next_state = `STATE_S_RESP;
            `STATE_S_WAIT_WREADY: if (M_AXI_WREADY) next_state = `STATE_S_RESP;
            `STATE_PC_DATA: if (M_AXI_RVALID) next_state = `STATE_IDLE;
            `STATE_L_DATA: if (M_AXI_RVALID) next_state = `STATE_IDLE;
            `STATE_S_RESP: if (M_AXI_BVALID) next_state = `STATE_IDLE;
        endcase
    end
    always @(posedge CLK or negedge RSTn)
        if (!RSTn) state <= `STATE_IDLE;
        else state <= next_state;

    // AXI Read
    always @(*) begin
        M_AXI_ARVALID = 1'b0;
        M_AXI_ARADDR  = `AXI_ADDR_WIDTH'b0;
        M_AXI_RREADY  = 1'b0;
        M_AXI_ARPROT  = 3'b0;
        case (state)
            `STATE_IDLE: begin
                M_AXI_ARVALID = pc_valid | read_enable;  // immediately forward valid signal
                M_AXI_ARADDR  = pc_valid ? pc : read_enable ? read_write_addr : `AXI_ADDR_WIDTH'b0;
            end
            `STATE_PC_WAIT_ARREADY: begin
                M_AXI_ARVALID = 1'b1;
                M_AXI_ARADDR  = pc_latched;
            end
            `STATE_L_WAIT_ARREADY: begin
                M_AXI_ARVALID = 1'b1;
                M_AXI_ARADDR  = read_write_addr;  // assume the caller latches it properly
            end
            `STATE_PC_DATA: M_AXI_RREADY = 1'b1;
            `STATE_L_DATA:  M_AXI_RREADY = 1'b1;
        endcase
    end

    // AXI Write
    always @(*) begin
        M_AXI_AWVALID = 1'b0;
        M_AXI_AWADDR  = `AXI_ADDR_WIDTH'b0;
        M_AXI_AWPROT  = 3'b0;
        M_AXI_WVALID  = 1'b0;
        M_AXI_WDATA   = `AXI_DATA_WIDTH'b0;
        M_AXI_WSTRB   = `AXI_STROBE_WIDTH'b0;
        M_AXI_BREADY  = 1'b0;
        case (state)
            `STATE_IDLE: begin
                // immediately forward valid signal (read operations have precedence)
                M_AXI_AWVALID = write_enable & !(read_enable) & !(pc_valid);
                M_AXI_AWADDR  = read_write_addr;
                M_AXI_WVALID  = write_enable & !(read_enable) & !(pc_valid);
                M_AXI_WDATA   = write_data;
                M_AXI_WSTRB   = write_strobe;
            end
            `STATE_S_WAIT_BOTH: begin
                M_AXI_AWVALID = 1'b1;
                M_AXI_AWADDR  = read_write_addr;
                M_AXI_WVALID  = 1'b1;
                M_AXI_WDATA   = write_data;
                M_AXI_WSTRB   = write_strobe;
            end
            `STATE_S_WAIT_AWREADY: begin
                M_AXI_AWVALID = 1'b1;
                M_AXI_AWADDR  = read_write_addr;
            end
            `STATE_S_WAIT_WREADY: begin
                M_AXI_WVALID = 1'b1;
                M_AXI_WDATA  = write_data;
                M_AXI_WSTRB  = write_strobe;
            end
            `STATE_S_RESP: begin
                M_AXI_BREADY = 1'b1;
            end
        endcase
    end

    // potentially we can avoid the latching here if the PC unit directly accepts the ready signal
    always @(posedge CLK or negedge RSTn)
        if (!RSTn) pc_latched <= `AXI_ADDR_WIDTH'b0;
        else if (next_state == `STATE_PC_WAIT_ARREADY) pc_latched <= pc;

    always @(posedge CLK or negedge RSTn)
        if (!RSTn) begin
            instruction <= `AXI_DATA_WIDTH'b0;
            read_data <= `AXI_DATA_WIDTH'b0;
            instruction_valid <= 1'b0;
            read_write_valid <= 1'b0;
        end else begin
            if (state == `STATE_PC_DATA & next_state == `STATE_IDLE) begin
                instruction <= M_AXI_RDATA;
                instruction_valid <= 1'b1;
            end else if (state == `STATE_L_DATA & next_state == `STATE_IDLE) begin
                read_data <= M_AXI_RDATA;
                read_write_valid <= 1'b1;
            end else if (state == `STATE_S_RESP & next_state == `STATE_IDLE) begin
                read_write_valid <= 1'b1;
            end else begin
                read_write_valid  <= 1'b0;
                instruction_valid <= 1'b0;
            end
        end

    always @(posedge CLK or negedge RSTn)
        if (!RSTn) begin
        end else begin
        end


endmodule
