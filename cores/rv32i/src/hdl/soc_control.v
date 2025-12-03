`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
//
// Create Date: 28.11.25
// Design Name:
// Module Name: soc_control
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions:
// Description: Control module responsible for communication between Zynq PS,
//              Fault Injection Module and the core. It contains AXI4 Lite Slave,
//              which it uses to receive requests from Zynq PS that can instruct the
//              module to:
//              - dump all the entire register file
//              - read a single register
//              - write to a single register (with or without a fault)
//
//              In order to work on the register file this module is capable of
//              issuing the signal cm_cpu_stop, which effectively blocks the clock signal
//              to all CPU components except for the register file.
//
// Dependencies: rv32i_params.vh
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"
`include "../include/axi_configuration.vh"

// Inside this AXI slave we need to multiplex between different sub components:
// - register file
// - other registers of the core (PC)
// - control options (starting / stopping the core)
// Selecting which of these to talk to based on the address.
// The lowest `SUB_ADDR_WIDTH bits are used to specify the address within the
// component.
// The next `SUB_SEL_WIDTH bits are used to specify which component to talk to.
// The upper bits are ignored so this AXI slave can be placed freely in the
// masters memory space.
//
//  Layout (h are the high bits, assummed to be used by the interconnect):
// - hhhh 01rr: control register r. one of the following
//   - 00: Status
//   - 01: Start core
//   - 02: Stop core
//   - 03: Step core
//   - 04: PC
// - hhhh 02rr: CPU register r (0 to 31 used to refer to x0 to x31)
`define SUB_ADDR_WIDTH 8
`define SUB_SEL_WIDTH 8
`define USED_ADDR_WIDTH (`SUB_SEL_WIDTH+`SUB_ADDR_WIDTH)
`define SUB_SEL_CTLR `SUB_SEL_WIDTH'h01
`define SUB_SEL_REGFILE `SUB_SEL_WIDTH'h02

// In theroy, _WAIT_DONE and _RESP could be condensed into one state where the
// result is immediately returned. However, at this state we do not really care
// about single cycles and otherwise we would end up with very long
// combinatorial paths.
// On the other hand, STATE_READ_RECV_ADDR does not exist since we can achive
// the same with just STATE_IDLE (AXI allows deasserting ARREADY) without
// introducing more complexity.
`define STATE_WIDTH 4
`define STATE_IDLE `STATE_WIDTH'h0            // ready to accept reads, or transition to write state
`define STATE_READ_ISSUE `STATE_WIDTH'h1      // issue read request to the sub component
`define STATE_READ_WAIT_DONE `STATE_WIDTH'h2  // collect result of read request
`define STATE_READ_RESP `STATE_WIDTH'h3       // return read response via AXI
`define STATE_WRITE_RECV_ADDR `STATE_WIDTH'h8 // ready to accept write address
`define STATE_WRITE_RECV_DATA `STATE_WIDTH'h9 // ready to accept write data
`define STATE_WRITE_ISSUE `STATE_WIDTH'hA     // issue write request to the sub component
`define STATE_WRITE_WAIT_DONE `STATE_WIDTH'hB // collect result of write request
`define STATE_WRITE_RESP `STATE_WIDTH'hC      // return write response via AXI

module soc_control (
    input CLK,
    input RSTn,

    // connections to RISC-V register file
    // output reg                       cm_cpu_stop,
    output reg [`REG_ADDR_WIDTH-1:0] regfile_addr,
    input      [    `DATA_WIDTH-1:0] regfile_read_data,
    output reg                       regfile_write_enable,
    output reg [    `DATA_WIDTH-1:0] regfile_write_data,

    // AXI4-lite connections
    // AXI write address
    output reg                         S_AXI_AWREADY,
    input                              S_AXI_AWVALID,
    input      [  `AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input      [  `AXI_PROT_WIDTH-1:0] S_AXI_AWPROT,
    // AXI write data and write strobe
    output reg                         S_AXI_WREADY,
    input                              S_AXI_WVALID,
    input      [  `AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input      [`AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB,
    // AXI write response
    output reg                         S_AXI_BVALID,
    output reg [  `AXI_RESP_WIDTH-1:0] S_AXI_BRESP,
    input                              S_AXI_BREADY,
    // AXI read address
    output reg                         S_AXI_ARREADY,
    input                              S_AXI_ARVALID,
    input      [  `AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input      [  `AXI_PROT_WIDTH-1:0] S_AXI_ARPROT,
    // AXI read data and response
    output reg                         S_AXI_RVALID,
    output reg [  `AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg [  `AXI_RESP_WIDTH-1:0] S_AXI_RRESP,
    input                              S_AXI_RREADY
);
    reg                       op_done;  // if the read/write was completed
    reg                       op_successful;  // if the read/write was successful
    reg [`AXI_DATA_WIDTH-1:0] read_data;

    // state machine
    reg [   `STATE_WIDTH-1:0] state;
    reg [   `STATE_WIDTH-1:0] next_state;
    always @(*) begin
        next_state = state;
        case (state)
            `STATE_IDLE: begin
                if (S_AXI_ARVALID) next_state = `STATE_READ_ISSUE;
                else if (S_AXI_AWVALID) next_state = `STATE_WRITE_RECV_ADDR;
            end
            `STATE_READ_ISSUE: next_state = `STATE_READ_WAIT_DONE;
            `STATE_READ_WAIT_DONE: if (op_done) next_state = `STATE_READ_RESP;
            `STATE_READ_RESP: if (S_AXI_RREADY) next_state = `STATE_IDLE;
            `STATE_WRITE_RECV_ADDR: if (S_AXI_AWVALID) next_state = `STATE_WRITE_RECV_DATA;
            `STATE_WRITE_RECV_DATA: if (S_AXI_WVALID) next_state = `STATE_WRITE_ISSUE;
            `STATE_WRITE_ISSUE: next_state = `STATE_WRITE_WAIT_DONE;
            `STATE_WRITE_WAIT_DONE: if (op_done) next_state = `STATE_WRITE_RESP;
            `STATE_WRITE_RESP: if (S_AXI_BREADY) next_state = `STATE_IDLE;
        endcase
    end
    always @(posedge CLK or negedge RSTn)
        if (!RSTn) state <= `STATE_IDLE;
        else state <= next_state;

    // AXI Read
    always @(*) begin
        S_AXI_ARREADY = 1'b0;
        S_AXI_RVALID  = 1'b0;
        S_AXI_RDATA   = `AXI_DATA_WIDTH'b0;
        S_AXI_RRESP   = `AXI_RESP_WIDTH'b0;
        case (state)
            `STATE_IDLE: S_AXI_ARREADY = 1'b1;
            `STATE_READ_RESP: begin
                S_AXI_RVALID = 1'b1;
                S_AXI_RDATA  = op_successful ? read_data : '0;
                S_AXI_RRESP  = op_successful ? `AXI_RESP_OKAY : `AXI_RESP_SLVERR;
            end
        endcase
    end

    // AXI Write
    always @(*) begin
        S_AXI_AWREADY = 1'b0;
        S_AXI_WREADY  = 1'b0;
        S_AXI_BVALID  = 1'b0;
        S_AXI_BRESP   = `AXI_RESP_WIDTH'b0;
        case (state)
            `STATE_WRITE_RECV_ADDR: S_AXI_AWREADY = 1'b1;
            `STATE_WRITE_RECV_DATA: S_AXI_WREADY = 1'b1;
            `STATE_WRITE_RESP: begin
                S_AXI_BVALID = 1'b1;
                S_AXI_BRESP  = op_successful ? `AXI_RESP_OKAY : `AXI_RESP_SLVERR;
            end
        endcase
    end

    // Latch data from AXI bus on transactions
    reg [ `USED_ADDR_WIDTH-1:0] latched_address;
    reg [  `AXI_DATA_WIDTH-1:0] latched_write_data;
    reg [`AXI_STROBE_WIDTH-1:0] latched_write_strobe;
    always @(posedge CLK or negedge RSTn)
        if (!RSTn) begin
            latched_address <= `AXI_ADDR_WIDTH'b0;
            latched_write_data <= `AXI_DATA_WIDTH'b0;
            latched_write_strobe <= `AXI_STROBE_WIDTH'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    if (S_AXI_ARVALID) latched_address <= S_AXI_ARADDR[`USED_ADDR_WIDTH-1:0];
                end
                `STATE_WRITE_RECV_ADDR: begin
                    if (S_AXI_AWVALID) latched_address <= S_AXI_AWADDR[`USED_ADDR_WIDTH-1:0];
                end
                `STATE_WRITE_RECV_DATA:
                if (S_AXI_WVALID) begin
                    latched_write_data   <= S_AXI_WDATA;
                    latched_write_strobe <= S_AXI_WSTRB;
                end
            endcase
        end

    // Read/write collect the responses
    reg regfile_op_successful;
    always @(*)
        if (state == `STATE_READ_WAIT_DONE || state == `STATE_WRITE_WAIT_DONE) begin
            case (sub_selector)
                `SUB_SEL_REGFILE: op_done = 1'b1;  // takes one cycle
                default:          op_done = 1'b1;  // invalid op always done
            endcase
        end else op_done = 1'b0;
    always @(posedge CLK or negedge RSTn)
        if (!RSTn) begin
            op_successful <= 1'b0;
            read_data <= '0;
        end else if (op_done) begin  // on state transition from _WAIT_DONE to _RESP
            case (sub_selector)
                `SUB_SEL_REGFILE: begin
                    op_successful <= regfile_op_successful;
                    read_data <= regfile_read_data;
                end
                default: begin
                    op_successful <= 1'b0;
                    read_data <= `DATA_WIDTH'b0;
                end
            endcase
        end

    wire [ `SUB_SEL_WIDTH-1:0] sub_selector;
    wire [`SUB_ADDR_WIDTH-1:0] sub_addr;
    assign sub_selector = latched_address[`USED_ADDR_WIDTH-1:`SUB_ADDR_WIDTH];
    assign sub_addr = latched_address[`SUB_ADDR_WIDTH-1:0];

    // Register File issue
    // There are only 32 Registers, so reads/write to larger address are not valid.
    // Furthermore, writes to x0 are not allowed and all 32 bits have to be written at once.
    wire [`REG_ADDR_WIDTH-1:0] regfile_sub_addr = sub_addr[`REG_ADDR_WIDTH-1:0];
    wire regfile_read_valid = (sub_addr[`SUB_ADDR_WIDTH-1:`REG_ADDR_WIDTH] == '0);
    wire regfile_write_valid = regfile_read_valid && (latched_write_strobe == '1);
    always @(*) begin
        regfile_addr = `REG_ADDR_WIDTH'b0;
        regfile_write_enable = 1'b0;
        regfile_write_data = `DATA_WIDTH'b0;
        case (state)
            `STATE_READ_ISSUE: begin
                regfile_addr = regfile_read_valid ? regfile_sub_addr : `REG_ADDR_WIDTH'b0;
            end
            `STATE_WRITE_ISSUE: begin
                regfile_addr = regfile_write_valid ? regfile_sub_addr : `REG_ADDR_WIDTH'b0;
                regfile_write_enable = regfile_write_valid;
                regfile_write_data = latched_write_data;
            end
            `STATE_READ_WAIT_DONE:  regfile_op_successful <= regfile_read_valid;
            `STATE_WRITE_WAIT_DONE: regfile_op_successful <= regfile_write_valid;
        endcase
    end



endmodule
