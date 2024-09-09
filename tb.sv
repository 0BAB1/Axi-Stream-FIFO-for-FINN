`timescale 1ns/1ps

// Very basic tesbench, not really here to test actually, just to see if last works
// in the context of a FIFO with a depth of 8 as it's all I need, no need for more (+ testbenches are annoying)

// Things to test :

// - Read / Write (normal)
// - Test TREADY and TVILID outputs when full and empty
// - Test R/W when both S & M want infos
// - Test TLAST handling

module tb;  // Testbench module name

    // Parameters
    parameter CLK_PERIOD = 10;  // Clock period in nanoseconds
    parameter IN_DATA_WIDTH = 8;
    parameter OUT_DATA_WIDTH = 32;

    // Clock and Reset signals
    reg clk;
    reg rst_n;

    wire [OUT_DATA_WIDTH-1:0]  output_signal;
    wire m_axis_tvalid;
    wire m_axis_tlast;
    wire s_axis_tready;

    reg m_axis_tready;
    reg  [IN_DATA_WIDTH-1:0]  input_signal; 
    reg s_axis_tvalid;

    // Instantiate the DUT (Custom FIFO)
    custom_fifo #(
    .IN_DATA_WIDTH(IN_DATA_WIDTH),
    .OUT_DATA_WIDTH(OUT_DATA_WIDTH)
    ) dut (
        // AXIS
        .clk,
        .rst_n,

        // (SLAVE) AI Model interface
        .s_axis_tvalid,
        .s_axis_tdata(input_signal),
        .s_axis_tready,

        // (MASTER) DMA Interface
        .m_axis_tvalid,
        .m_axis_tdata(output_signal),
        .m_axis_tlast,
        .m_axis_tready
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 0;                // Assert reset (active low)
        # (2 * CLK_PERIOD);       // Wait for 2 clock periods
        rst_n = 1;                // Deassert reset
    end

    // Stimulus process
    initial begin
        // Initialize inputs
        input_signal = 8'b0;
        s_axis_tvalid = 1'b0;
        m_axis_tready = 1'b0;

        // Wait for reset deassertion
        @(posedge rst_n);
        @(posedge clk);

        // Write (normal)
        s_axis_tvalid = 1'b1;
        input_signal = 8'hAA;
        @(posedge clk);
        input_signal = 8'h55;
        @(posedge clk);
        input_signal = 8'hFF;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        // Write another value just before it gets full to check
        // if we are on the edge 
        input_signal = 8'hBB;
        @(posedge clk);
        // test TREADY and TVALID outputs when full
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        s_axis_tvalid = 1'b0;

        // Read (normal)
        m_axis_tready = 1'b1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        // Test TLAST handling
        @(posedge clk);
        // test TREADY and TVALID outputs when empty
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        // End of simulation
        #100;  // Wait for 100 ns (or any other duration)
        $finish;  // End simulation
    end

    // Monitor
    initial begin
        $monitor("Time: %0t | input_signal = %h | output_signal = %h", $time, input_signal, output_signal);
    end

endmodule
