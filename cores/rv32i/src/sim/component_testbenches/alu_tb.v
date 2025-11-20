`timescale 1ns / 1ps

`include "../../include/rv32i_params.vh"
`include "../../include/rv32i_control.vh"


module alu_tb();

    // ALU inputs
    reg  [`ALU_CTRL_WIDTH-1:0] alu_ctrl;
    reg  [`DATA_WIDTH-1:0]     src1;
    reg  [`DATA_WIDTH-1:0]     src2;

    // ALU outputs
    wire [`DATA_WIDTH-1:0]     alu_result;
    wire                       take_branch;

    alu dut(
        .alu_ctrl(alu_ctrl),
        .src1(src1),
        .src2(src2),
        .result(alu_result),
        .take_branch(take_branch)
    );

    task display_results;
        begin
            $display("Time=%0t | ctrl=%b | src1=%h | src2=%h \n| result=%h",
                     $time,
                     alu_ctrl,
                     src1,
                     src2,
                     alu_result);
        end
    endtask

    initial begin
        // Initialize signals
        alu_ctrl = 0;
        src1     = 0;
        src2     = 0;

        // Test 1: Reset state
        #10;
        alu_ctrl = `ALU_CTRL_NOP;
        src1     = 32'h0;
        src2     = 32'h0;
        #1;
        display_results();
        if (alu_result != 32'h0)
            $display("[ERROR] expected %h, got %h", 32'h0, alu_result);

        // --- ALU OP tests -----------------------------------------------------

        // ADD
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_ADD_SUB};
        src1 = 32'd10;
        src2 = 32'd20;
        #1;
        display_results();
        if (alu_result != 32'd30)
            $display("[ERROR] ADD failed: got %h", alu_result);

        // SUB
        #10;
        alu_ctrl = {1'b0, 1'b1, `F3_ADD_SUB};
        src1 = 32'd50;
        src2 = 32'd20;
        #1;
        display_results();
        if (alu_result != 32'd30)
            $display("[ERROR] SUB failed: got %h", alu_result);

        // AND
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_AND};
        src1 = 32'hFF00FF00;
        src2 = 32'h0F0F0F0F;
        #1;
        display_results();
        if (alu_result != (src1 & src2))
            $display("[ERROR] AND failed: got %h", alu_result);

        // OR
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_OR};
        src1 = 32'hFF00FF00;
        src2 = 32'h0F0F0F0F;
        #1;
        display_results();
        if (alu_result != (src1 | src2))
            $display("[ERROR] OR failed: got %h", alu_result);

        // XOR
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_XOR};
        src1 = 32'hAAAA5555;
        src2 = 32'hFFFF0000;
        #1;
        display_results();
        if (alu_result != (src1 ^ src2))
            $display("[ERROR] XOR failed: got %h", alu_result);

        // SLL
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_SLL};
        src1 = 32'h1;
        src2 = 32'd4;
        #1;
        display_results();
        if (alu_result != 32'h10)
            $display("[ERROR] SLL failed: got %h", alu_result);

        // SRL
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_SRL_SRA};
        src1 = 32'hFFFFFF80;
        src2 = 32'd4;
        #1;
        display_results();
        if (alu_result != 32'h0FFFFFF8)
            $display("[ERROR] SRL failed: got %h", alu_result);

        // SRA
        #10;
        alu_ctrl = {1'b0, 1'b1, `F3_SRL_SRA};
        src1 = 32'hFFFFFF80;
        src2 = 32'd4;
        #1;
        display_results();
        if (alu_result != 32'hFFFFFFF8)
            $display("[ERROR] SRA failed: got %h", alu_result);

        // SLTI
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_SLTI};
        src1 = -5;
        src2 = 7;
        #1;
        display_results();
        if (alu_result != 32'h1)
            $display("[ERROR] SLTI failed: got %h", alu_result);

        // SLTIU
        #10;
        alu_ctrl = {1'b0, 1'b0, `F3_SLTIU};
        src1 = 32'hFFFFFFFE;
        src2 = 32'h00000001;
        #1;
        display_results();
        if (alu_result != 32'h0)
            $display("[ERROR] SLTIU failed: got %h", alu_result);

        // --- BRANCH tests -----------------------------------------------------

        // BEQ
        #10;
        alu_ctrl = {1'b1, 1'b0, `F3_BEQ};
        src1 = 32'hA5A5A5A5;
        src2 = 32'hA5A5A5A5;
        #1;
        display_results();
        if (alu_result != 32'h1)
            $display("[ERROR] BEQ failed: got %h", alu_result);

        // BNE
        #10;
        alu_ctrl = {1'b1, 1'b0, `F3_BNE};
        src1 = 32'h1234;
        src2 = 32'h4321;
        #1;
        display_results();
        if (alu_result != 32'h1)
            $display("[ERROR] BNE failed: got %h", alu_result);

        // BLT
        #10;
        alu_ctrl = {1'b1, 1'b0, `F3_BLT};
        src1 = -5;
        src2 = 7;
        #1;
        display_results();
        if (alu_result != 32'h1)
            $display("[ERROR] BLT failed: got %h", alu_result);

        // BGE
        #10;
        alu_ctrl = {1'b1, 1'b0, `F3_BGE};
        src1 = -5;
        src2 = 7;
        #1;
        display_results();
        if (alu_result != 32'h0)
            $display("[ERROR] BGE failed: got %h", alu_result);

        // BLTU
        #10;
        alu_ctrl = {1'b1, 1'b0, `F3_BLTU};
        src1 = 32'h00000001;
        src2 = 32'h00000002;
        #1;
        display_results();
        if (alu_result != 32'h1)
            $display("[ERROR] BLTU failed: got %h", alu_result);

        // BGEU
        #10;
        alu_ctrl = {1'b1, 1'b0, `F3_BGEU};
        src1 = 32'h00000002;
        src2 = 32'h00000001;
        #1;
        display_results();
        if (alu_result != 32'h1)
            $display("[ERROR] BGEU failed: got %h", alu_result);

        #10;
        $display("All tests completed");
        $finish;
    end


endmodule
