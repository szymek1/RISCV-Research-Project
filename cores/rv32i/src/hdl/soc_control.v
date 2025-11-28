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
`include "../include/soc_control/axi4lite_configuration.vh"


module soc_control (
    input clk,
    input rst,

    // connections to RISC-V core
    output                                   cm_cpu_stop,
    output                                   cm_regfile_we,
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

    // Read/Write indexes (point to specific word)
    wire [`C_ADDR_REG_BITS-1:0] read_index  = S_AXI_ARADDR[`C_AXI_ADDR_WIDTH-1:`C_ADDR_LSB];
    wire [`C_ADDR_REG_BITS-1:0] write_index = S_AXI_AWADDR[`C_AXI_ADDR_WIDTH-1:`C_ADDR_LSB];

    // Internal registers
    // Write channel internal registers
    reg                         S_AXI_AWREADY_;
    reg                         S_AXI_WREADY_;
    reg                         S_AXI_BVALID_;
    reg [1:0]                   S_AXI_BRESP_;
    reg [`C_ADDR_REG_BITS-1:0]  axi_awaddr_latched;  // latched write address
    reg                         slv_reg_wren;        // internal write-enable pulse for user logic

    // Read channel internal registers
    reg                         S_AXI_ARREADY_;
    reg                         S_AXI_RVALID_;
    reg [1:0]                   S_AXI_RRESP_;
    reg [`C_AXI_DATA_WIDTH-1:0] S_AXI_RDATA_;        // pipelined read data output
    reg [`C_ADDR_REG_BITS-1:0]  axi_araddr_latched;  // latched read address

    // Output wires
    // Write related
    assign S_AXI_AWREADY = S_AXI_AWREADY_;
    assign S_AXI_WREADY  = S_AXI_WREADY_;
    assign S_AXI_BVALID  = S_AXI_BVALID_;
    assign S_AXI_BRESP   = S_AXI_BRESP_;

    // Read related
    assign S_AXI_ARREADY = S_AXI_ARREADY_;
    assign S_AXI_RVALID  = S_AXI_RVALID_;
    assign S_AXI_RRESP   = S_AXI_RRESP_;
    assign S_AXI_RDATA   = S_AXI_RDATA_;

    // Core stalling logic
    localparam CPU_RUNNING    = 2'b00;
    localparam CPU_STOP_WAIT  = 2'b01; // allow register file to settle in order to avoid latching on old data
    localparam CPU_STOPPED    = 2'b10;
    reg        cpu_state      = CPU_RUNNING;

    wire       read_complete  = S_AXI_RVALID_ && S_AXI_RREADY;
    wire       write_complete = S_AXI_BVALID_ && S_AXI_BREADY;

    always @(posedge clk or negedge rst) begin
        if (rst) begin
            cpu_state <= CPU_RUNNING;
        end else begin
            case (cpu_state)
                CPU_RUNNING   : cpu_state <= (S_AXI_ARVALID  || S_AXI_AWVALID)  ? CPU_STOP_WAIT : CPU_STOPPED;
                CPU_STOP_WAIT : cpu_state <= CPU_STOPPED;
                CPU_STOPPED   : cpu_state <= (read_complete || write_complete) ? CPU_RUNNING   : CPU_STOPPED;
                default       : cpu_state <= CPU_RUNNING;
            endcase
        end
    end
    
    assign cm_cpu_stop = (cpu_state == CPU_STOPPED) ? 1'b1 : 1'b0;

    // Read process
    reg is_axi_read;
    always @(posedge clk or negedge rst) begin
        if (rst) begin
            is_axi_read        <= 1'b0;
            S_AXI_ARREADY_     <= 1'b0; 
            S_AXI_RVALID_      <= 1'b0;
            // axi_araddr_latched <= 0;
            S_AXI_RDATA_       <= 0;
            S_AXI_RRESP_       <= `AXI_RESP_OKAY;
        end else begin
            if (S_AXI_ARVALID && !S_AXI_ARREADY_ && !is_axi_read && cpu_state == CPU_STOPPED) begin
                // Making sure that SOC Control Module managed to stop the CPU
                S_AXI_ARREADY_ <= 1'b1;
                is_axi_read    <= 1'b1;
            end else if (S_AXI_ARVALID && S_AXI_ARREADY_) begin
                // Address handshake: slave is by default ready so the handshake happends immediately
                //                    once the master issue the address
                is_axi_read        <= 1'b1;
                S_AXI_ARREADY_     <= 1'b0;              
                S_AXI_RVALID_      <= 1'b1;  // data will be valid in the next cycle
                S_AXI_RRESP_       <= `AXI_RESP_OKAY;
                S_AXI_RDATA_       <= cm_read_regfile_dat;
            end else if (S_AXI_RREADY && S_AXI_RVALID_) begin
                // Transaction complete: master accepts the data
                is_axi_read        <= 1'b0;
                S_AXI_RVALID_      <= 1'b0;
                S_AXI_ARREADY_     <= 1'b1;  // heres ready for the new read transaction
            end
        end
    end

    // Write process
    reg is_axi_write;
    always @(posedge clk or negedge rst) begin
        if (rst) begin
            is_axi_write       <= 1'b0;
            S_AXI_AWREADY_     <= 1'b0; 
            S_AXI_WREADY_      <= 1'b0;
            S_AXI_BVALID_      <= 1'b0;
            S_AXI_BRESP_       <= `AXI_RESP_OKAY;
        end else begin
            if (S_AXI_AWVALID && !S_AXI_AWREADY_ && !is_axi_write && cpu_state == CPU_STOPPED) begin
                // Making sure that SOC Control Module managed to stop the CPU
                S_AXI_AWREADY_ <= 1'b1;
                is_axi_write   <= 1'b1;
            end else if (S_AXI_AWVALID && S_AXI_AWREADY_) begin
                // Address handshake: slave is by default READY and master has to issue VALID
                is_axi_write       <= 1'b1;
                S_AXI_AWREADY_     <= 1'b0;
                S_AXI_WREADY_      <= 1'b1;  
            end else if (S_AXI_WVALID && S_AXI_WREADY_) begin
                // Data handshake: slave is ready to accept new write data and it's waiting for the master to issue VALID
                is_axi_write       <= 1'b1;
                S_AXI_WREADY_      <= 1'b0;                     
                S_AXI_BVALID_      <= 1'b1;       
                S_AXI_BRESP_       <= `AXI_RESP_OKAY;
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                // Response
                is_axi_write       <= 1'b0;
                S_AXI_BVALID_      <= 1'b0;
                S_AXI_AWREADY_     <= 1'b1; // heres ready for the new write transaction
            end
        end
    end

    // assigning the correct read or write address the signal controlling the register file
    // since there is only one address line shared by th read and write address two operations
    // cannot happend at once
    assign cm_read_write_regfile_addr = (is_axi_read && !is_axi_write) ? read_index  : 
                                        (!is_axi_read && is_axi_write) ? write_index : 0;
    
    assign cm_regfile_we = is_axi_write;

    // Register write and reset process
    // There's no specific case for resetting the register file here since it happens
    // already inside the core
    integer byte_id;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            if (is_axi_write) begin
                for (byte_id = 0; byte_id < `C_AXI_STROBE_WIDTH; byte_id = byte_id + 1) begin
                    if (S_AXI_WSTRB[byte_id]) begin
                        // Example to illustrate how strobe mechanism works:
                        // if byte_id = 0 then [(0*8)+:8] -> [0+:8] this selects [7:0]
                        // the line performs: 
                        // cm_write_regfile_dat[cm_read_write_regfile_addr][7:0]         <= S_AXI_WDATA[7:0]
                        cm_write_regfile_dat[cm_read_write_regfile_addr][(byte_id*8)+:8] <= S_AXI_WDATA[(byte_id*8)+:8];
                    end
                end
            end
        end
    end

endmodule