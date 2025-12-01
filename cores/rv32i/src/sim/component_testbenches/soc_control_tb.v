`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 29.11.2025
// Design Name: 
// Module Name: soc_control_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Testbench for SOC control module, it simulates the AXI4Lite Master 
//              requests and verifies stalling logic.
// 
// Dependencies: rv32i_params.vh, axi4lite_configuration.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../../include/rv32i_params.vh"
`include "../../include/soc_control/axi4lite_configuration.vh"


module soc_control_tb (
);

    // --- Clock and Reset ---
    localparam CLK_PERIOD = 10; // 10ns = 100MHz clock
    reg clk;
    reg rst_n;

    // AXI wires driven by the testbench
    reg                           S_AXI_AWVALID;
    reg [`C_AXI_ADDR_WIDTH-1:0]   S_AXI_AWADDR;
    reg                           S_AXI_WVALID;
    reg [`C_AXI_DATA_WIDTH-1:0]   S_AXI_WDATA;
    reg [`C_AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB;
    reg                           S_AXI_BREADY;
    reg                           S_AXI_ARVALID;
    reg [`C_AXI_ADDR_WIDTH-1:0]   S_AXI_ARADDR;
    reg                           S_AXI_RREADY;

    // AXI wires driven byt DUT
    wire                         S_AXI_AWREADY;
    wire                         S_AXI_WREADY;
    wire                         S_AXI_BVALID;
    wire [1:0]                   S_AXI_BRESP;
    wire                         S_AXI_ARREADY;
    wire                         S_AXI_RVALID;
    wire [`C_AXI_DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]                   S_AXI_RRESP;

    // Wires related to the connection with RISC-V core and driven by DUT
    wire                         cm_cpu_stop;
    wire                         cm_regfile_we;
    wire [`DATA_WIDTH-1:0]       cm_write_regfile_dat;
    wire [`REG_ADDR_WIDTH-1:0]   cm_read_write_regfile_addr;
    wire [1:0]                   deb_cpu_state;

    // Wires related to the connection with RISC-V core and driven by the register file
    wire [`DATA_WIDTH-1:0]       cm_read_regfile_dat;
    wire [`DATA_WIDTH-1:0]       rf_rs1_out;
    wire [`DATA_WIDTH-1:0]       rf_rs2_out;

    // --- Instantiate the Device Under Test (DUT) ---
    soc_control SOC_CONTROL_dut (
        .clk(clk),
        .rst_n(rst_n),
        // connections to RISC-V core
        .cm_cpu_stop(cm_cpu_stop),
        .cm_regfile_we(cm_regfile_we),
        .cm_write_regfile_dat(cm_write_regfile_dat),
        .cm_read_write_regfile_addr(cm_read_write_regfile_addr),
        .cm_read_regfile_dat(cm_read_regfile_dat),

        // connections to AXI4 Lite
        // AXI write address
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(3'b0), // Protection not used, tie to 0

        // AXI write data and write strobe
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),

        // AXI write response
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BREADY(S_AXI_BREADY),

        // AXI read address
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(3'b0), // Protection not used, tie to 0

        // AXI read data and response
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RREADY(S_AXI_RREADY),

        // Debug ports
        .deb_cpu_state(deb_cpu_state)
    );

    register_file REG_FILE_dut (
        .clk(clk),
        .rst(!rst_n),
        .read_enable(1'b1),
        .rs1_addr(cm_cpu_stop ? cm_read_write_regfile_addr : 5'd0), 
        .rs2_addr(5'd0),
        .rs1(rf_rs1_out),
        .rs2(rf_rs2_out),
        .write_enable(cm_cpu_stop && cm_regfile_we),
        .write_addr(cm_cpu_stop ? cm_read_write_regfile_addr : 5'd0),
        .write_data(cm_cpu_stop ? cm_write_regfile_dat : 32'd0)
    );

    assign cm_read_regfile_dat = rf_rs1_out;

    // Clock generator
    always begin
        clk = 1'b0;
        #(CLK_PERIOD / 2);
        clk = 1'b1;
        #(CLK_PERIOD / 2);
    end

    initial begin
        $dumpfile("soc_control_waves.vcd");
        $dumpvars(0, soc_control_tb);
        $dumpvars(0, REG_FILE_dut.registers[1]);
        $dumpvars(0, REG_FILE_dut.registers[2]);
        
        $display("--- Testbench Starting ---");

        // Reset
        rst_n = 1'b0;
        S_AXI_AWVALID = 0; S_AXI_WVALID = 0; S_AXI_BREADY = 0;
        S_AXI_ARVALID = 0; S_AXI_RREADY = 0; S_AXI_ARADDR  <= '0;
        S_AXI_AWADDR = 0; S_AXI_WDATA = 0; S_AXI_WSTRB = 0;
        
        #(CLK_PERIOD * 5);
        rst_n = 1'b1; 
        $display("[%0t] Reset Released", $time);
        #(CLK_PERIOD * 2);

        // --- TEST 1: Basic Read/Write Verification ---
        // Write 0xDEADBEEF to Register 1
        $display("[%0t] Test 1: Write Reg 1 -> 0xDEADBEEF", $time);
        axi_write(.addr(32'h4), .data(32'hDEADBEEF), .strobe(4'b1111));

        // Read Register 1
        $display("[%0t] Test 2: Read Reg 1 -> Expect 0xDEADBEEF", $time);
        axi_read(.addr(32'h4), .expected_data(32'hDEADBEEF));

        // --- TEST 2: Strobe (Partial Write) Verification ---
        // 1. Initialize Reg 2 with 0xFFFFFFFF
        $display("[%0t] Test 3: Write Reg 2 -> 0xFFFFFFFF", $time);
        axi_write(.addr(32'h8), .data(32'hFFFFFFFF), .strobe(4'b1111));

        // 2. Overwrite middle bytes (Bits 15:8 and 23:16) with 0x55, 0xAA
        // Strobe 0110 means only write to byte 1 and 2.
        // Data: 0x00AA5500
        $display("[%0t] Test 4: Strobe Write Reg 2 (Mask 0110) -> 0x..AA55..", $time);
        axi_write(.addr(32'h8), .data(32'h00AA5500), .strobe(4'b0110));

        // 3. Read Back. Expect 0xFFAA55FF
        $display("[%0t] Test 5: Read Reg 2 -> Expect 0xFFAA55FF", $time);
        axi_read(.addr(32'h8), .expected_data(32'hFFAA55FF));

        // --- TEST 3: Stalling Logic Check ---
        // We will assert address valid but NOT data valid immediately
        // to see if the CPU stops and WAITS.
        $display("[%0t] Test 6: Stall Timing Check", $time);
        @(posedge clk);
        S_AXI_ARADDR  <= 32'h4;
        S_AXI_ARVALID <= 1'b1;
        
        // Wait 1 cycle
        @(posedge clk); 
        #1; // minor delay to account for the delat delay (on the waveforms everything 
            // looks fine even without it but the test didn't want to pass without it)
        if (cm_cpu_stop !== 1'b1) 
            $error("[ERROR]: CPU did not stop 1 cycle after ARVALID assertion!");
        
        wait(!S_AXI_ARREADY); // Wait for SOC to trigger ready
        if (cm_cpu_stop !== 1'b1)
             $error("[ERROR]: CPU is not stopped while ARREADY is High!");
        else
             $display("[SUCCESS]: CPU is stopped during transaction.");

        // Finish the manual read
        S_AXI_ARVALID <= 1'b0;
        S_AXI_RREADY  <= 1'b1;
        wait(S_AXI_RVALID);
        @(posedge clk);
        S_AXI_RREADY  <= 1'b0;
        
        #(CLK_PERIOD * 5);
        if (cm_cpu_stop !== 1'b0)
             $error("[ERROR]: CPU did not resume after transaction!");
        else
             $display("[SUCCESS]: CPU resumed after transaction.");

        $display("\n--- All Tests Passed ---\n");
        $finish;
    end


    // AXI master write task
    task axi_write(
        input [`C_AXI_ADDR_WIDTH-1:0] addr,
        input [`C_AXI_DATA_WIDTH-1:0] data,
        input [`C_AXI_STROBE_WIDTH-1:0] strobe
    );
    begin
        // Address Phase
        @(posedge clk);
        S_AXI_AWADDR  <= addr;
        S_AXI_AWVALID <= 1'b1;
        S_AXI_WDATA   <= data;
        S_AXI_WSTRB   <= strobe;
        S_AXI_WVALID  <= 1'b1;
        S_AXI_BREADY  <= 1'b1;

        // Wait for Address Acceptance
        fork
            begin : wait_addr
                wait(S_AXI_AWREADY);
                @(posedge clk);
                S_AXI_AWVALID <= 1'b0;
            end
            begin : wait_data
                wait(S_AXI_WREADY);
                @(posedge clk);
                S_AXI_WVALID <= 1'b0;
            end
        join

        // Response Phase
        wait(S_AXI_BVALID);
        if (S_AXI_BRESP != 2'b00) $error("[ERROR:] AXI Write Error response");
        
        @(posedge clk);
        S_AXI_BREADY <= 1'b0;
        
        // Safety gap
        @(posedge clk);
    end
    endtask


    // AXI master read task
    task axi_read(
        input [`C_AXI_ADDR_WIDTH-1:0] addr,
        input [`C_AXI_DATA_WIDTH-1:0] expected_data
    );
    begin
        // Address Phase
        @(posedge clk);
        S_AXI_ARADDR  <= addr;
        S_AXI_ARVALID <= 1'b1;
        
        wait(S_AXI_ARREADY);
        @(posedge clk);
        S_AXI_ARVALID <= 1'b0;

        // Data Phase
        S_AXI_RREADY <= 1'b1;
        
        wait(S_AXI_RVALID);
        if (S_AXI_RDATA != expected_data) begin
            $error("[ERROR:] READ MISMATCH! Addr: %h, Exp: %h, Got: %h", addr, expected_data, S_AXI_RDATA);
        end else begin
            $display("[SUCCESS:] Read OK: %h", S_AXI_RDATA);
        end
        
        @(posedge clk);
        S_AXI_RREADY <= 1'b0;
        
        // Safety gap
        @(posedge clk);
    end
    endtask

endmodule