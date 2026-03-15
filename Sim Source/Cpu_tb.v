`timescale 1ns / 1ps

module cpu_tb;

    // Signals
    reg clk;
    reg reset;

    integer cycle;
    integer last_pc;

    // DUT
    cpu UUT (
        .clk(clk),
        .reset(reset)
    );

    // Clock: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // Main test
    initial begin
        // Wave dump
        $dumpfile("cpu.vcd");
        $dumpvars(0, cpu_tb);

        // Init
        clk     = 0;
        reset   = 1;
        cycle   = 0;
        last_pc = -1;

        // Load program
        $readmemh("test.mem", UUT.imem);

        // Reset pulse
        #20;
        reset = 0;

        // Safety timeout (1000 cycles)
        #10000;
        $display("TIMEOUT: simulation ran too long");
        $finish;
    end

    // Cycle counter
    always @(posedge clk) begin
        if (reset)
            cycle <= 0;
        else
            cycle <= cycle + 1;
    end

    // Runtime monitoring
    always @(posedge clk) begin
        if (!reset) begin
            $display(
                "CYCLE=%0d | PC=%h | INSTR=%h",
                cycle,
                UUT.pc,
                UUT.instr
            );

            // Detect PC stuck (likely infinite loop)
            if (UUT.pc == last_pc) begin
                $display("PC stuck at %h. Halting.", UUT.pc);
                $finish;
            end

            last_pc = UUT.pc;
        end
    end

endmodule
