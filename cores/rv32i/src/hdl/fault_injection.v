`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: 
// 
// Create Date: 10/23/2025
// Design Name: 
// Module Name: fault_injection
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Fault injection module for RISC-V processor. Decodes fault 
//              injection instructions and generates control signals to inject
//              faults into various processor components.
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "../include/rv32i_params.vh"

module fault_injection(
    input  wire        clk,
    input  wire        rst,
    input  wire        fault_enable,           // Enable fault injection
    input  wire [31:0] fault_instruction,      // Fault injection instruction
    input  wire        fault_trigger,          // Trigger signal to execute fault
    
    // Register file fault injection outputs
    output reg         regfile_fault_enable,   // Enable fault in register file
    output reg  [4:0]  regfile_target_reg,     // Target register (x0-x31)
    output reg  [4:0]  regfile_target_bit,     // Target bit position (0-31)
    output reg         regfile_fault_type,     // 0: bit flip, 1: stuck-at (future expansion)
    
    // Memory BRAM fault injection outputs
    output reg         memory_fault_enable,    // Enable fault in memory BRAM
    output reg  [31:0] memory_target_addr,     // Target memory address
    output reg  [4:0]  memory_target_bit,      // Target bit position (0-31)
    output reg         memory_fault_type,      // 0: bit flip, 1: stuck-at (future expansion)
    
    // Status outputs
    output reg         fault_active,           // Indicates fault is currently active
    output reg  [7:0]  fault_count,            // Count of injected faults
    output reg  [3:0]  fault_component         // Which component is targeted
);

    // Fault instruction encoding:
    // [31:28] - Component select (4 bits)
    //   0000: Register file
    //   0001: ALU (future)
    //   0010: Memory BRAM
    //   0011: Control unit (future)
    //   Others: Reserved
    // [27:24] - Fault type (4 bits)
    //   0000: Bit flip
    //   0001: Stuck-at-0 (future)
    //   0010: Stuck-at-1 (future)
    //   Others: Reserved
    // [23:19] - Target register/component address (5 bits)
    //   For register file: register number (0-31)
    //   For memory: word index (0-31) - actual address = index * 4
    // [18:14] - Target bit position (5 bits)
    // [13:0]  - Reserved for future use

    // Instruction field extraction
    wire [3:0] component_select = fault_instruction[31:28];
    wire [3:0] fault_type       = fault_instruction[27:24];
    wire [4:0] target_address   = fault_instruction[23:19];
    wire [4:0] bit_position     = fault_instruction[18:14];

    // Component encoding definitions
    localparam [3:0] COMPONENT_REGFILE = 4'b0000;
    localparam [3:0] COMPONENT_ALU     = 4'b0001;
    localparam [3:0] COMPONENT_MEMORY  = 4'b0010;
    localparam [3:0] COMPONENT_CONTROL = 4'b0011;

    // Fault type encoding definitions
    localparam [3:0] FAULT_BIT_FLIP   = 4'b0000;
    localparam [3:0] FAULT_STUCK_AT_0 = 4'b0001;
    localparam [3:0] FAULT_STUCK_AT_1 = 4'b0010;

    // Internal registers
    reg fault_pending;
    reg [31:0] pending_instruction;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all outputs
            regfile_fault_enable <= 1'b0;
            regfile_target_reg   <= 5'b0;
            regfile_target_bit   <= 5'b0;
            regfile_fault_type   <= 1'b0;
            memory_fault_enable  <= 1'b0;
            memory_target_addr   <= 32'b0;
            memory_target_bit    <= 5'b0;
            memory_fault_type    <= 1'b0;
            fault_active         <= 1'b0;
            fault_count          <= 8'b0;
            fault_component      <= 4'b0;
            fault_pending        <= 1'b0;
            pending_instruction  <= 32'b0;
        end else begin
            // Default: clear fault signals
            regfile_fault_enable <= 1'b0;
            memory_fault_enable  <= 1'b0;
            fault_active         <= 1'b0;

            // Store fault instruction when fault_enable is asserted
            if (fault_enable && !fault_pending) begin
                fault_pending       <= 1'b1;
                pending_instruction <= fault_instruction;
            end

            // Execute fault when trigger is asserted and we have a pending instruction
            if (fault_trigger && fault_pending) begin
                fault_pending <= 1'b0;
                fault_active  <= 1'b1;
                fault_count   <= fault_count + 1;

                // Decode the pending instruction
                case (pending_instruction[31:28]) // component_select
                    COMPONENT_REGFILE: begin
                        fault_component <= COMPONENT_REGFILE;
                        
                        // Validate register address (x0-x31)
                        if (pending_instruction[23:19] <= 5'd31) begin
                            regfile_fault_enable <= 1'b1;
                            regfile_target_reg   <= pending_instruction[23:19];
                            
                            // Validate bit position (0-31 for 32-bit registers)
                            if (pending_instruction[18:14] <= 5'd31) begin
                                regfile_target_bit <= pending_instruction[18:14];
                            end else begin
                                regfile_target_bit <= 5'd0; // Default to bit 0 if invalid
                            end
                            
                            // For now, only support bit flip
                            regfile_fault_type <= (pending_instruction[27:24] == FAULT_BIT_FLIP) ? 1'b0 : 1'b0;
                        end
                    end
                    
                    COMPONENT_ALU: begin
                        fault_component <= COMPONENT_ALU;
                        // Future implementation for ALU faults
                    end
                    
                    COMPONENT_MEMORY: begin
                        fault_component <= COMPONENT_MEMORY;
                        
                        // Validate memory word index (0-31 for simplicity in testbench)
                        // In real implementation, this would be larger based on BRAM size
                        if (pending_instruction[23:19] <= 5'd31) begin
                            memory_fault_enable <= 1'b1;
                            // Convert word index to byte address (multiply by 4)
                            memory_target_addr  <= {25'b0, pending_instruction[23:19], 2'b00};
                            
                            // Validate bit position (0-31 for 32-bit words)
                            if (pending_instruction[18:14] <= 5'd31) begin
                                memory_target_bit <= pending_instruction[18:14];
                            end else begin
                                memory_target_bit <= 5'd0; // Default to bit 0 if invalid
                            end
                            
                            // For now, only support bit flip
                            memory_fault_type <= (pending_instruction[27:24] == FAULT_BIT_FLIP) ? 1'b0 : 1'b0;
                        end
                    end
                    
                    COMPONENT_CONTROL: begin
                        fault_component <= COMPONENT_CONTROL;
                        // Future implementation for control unit faults
                    end
                    
                    default: begin
                        fault_component <= 4'hF; // Invalid component
                    end
                endcase
            end
        end
    end

endmodule
