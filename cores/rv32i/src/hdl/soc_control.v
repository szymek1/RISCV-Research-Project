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


module soc_control (
    input clk,
    input rst,

    // connections to RISC-V core
    output                                   cm_cpu_stop,
    output [`DATA_WIDTH-1:0]                 cm_write_regfile_dat,
    input  [`DATA_WIDTH-1:0]                 cm_read_regfile_dat,
    input  [`REG_ADDR_WIDTH-1:0]             cm_read_write_regfile_addr,

    // connections to AXI4 Lite 
    // AXI write address
	output						             S_AXI_AWREADY,  
	input						             S_AXI_AWVALID,  
	input  [`C_AXI_ADDR_WIDTH-1:0]           S_AXI_AWADDR,  
	input  [2:0]				             S_AXI_AWPROT,   

	// AXI write data and write strobe
	output						             S_AXI_WREADY,   
	input						             S_AXI_WVALID,    
                                                   
	input   [`C_AXI_DATA_WIDTH-1:0]		     S_AXI_WDATA,    
	input   [`C_AXI_STROBE_WIDTH-1:0]	     S_AXI_WSTRB,    

	// AXI write response
	output						             S_AXI_BVALID,    
	output	[1:0]				             S_AXI_BRESP,    
                                                   
	input						             S_AXI_BREADY,   
                                                                   

	// AXI read address
	output						             S_AXI_ARREADY,  
	input						             S_AXI_ARVALID,  
	input	[`C_AXI_ADDR_WIDTH-1:0]          S_AXI_ARADDR,   
	input	[2:0]				             S_AXI_ARPROT,   

	// AXI read data and response
	output						             S_AXI_RVALID,   
	output	[`C_AXI_DATA_WIDTH-1:0]		     S_AXI_RDATA,    
	output	[1:0]				             S_AXI_RRESP,                                                                   
	input						             S_AXI_RREADY,   
);
endmodule