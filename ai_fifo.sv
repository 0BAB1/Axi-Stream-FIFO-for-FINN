// This module is a custom AXIS FIFO to patch the lack of support
// For using FINN stiched IP with Xilinx "vinilla DMA"

// It implements a dumb FIFO except TLAST is only implemented on the MASTER interface.

// Made for the "PyTorch to FPGA" Course

module custom_fifo #(
    parameter DEPTH = 8,
    parameter DATA_WIDTH = 8
) (
    // AXIS
    input wire clk,
    input wire rst_n,

    // (SLAVE) AI Model interface
    input wire s_axis_tvalid,
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    output wire s_axis_tready,

    // (MASTER) DMA Interface
    output wire m_axis_tvalid,
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tlast,
    input wire m_axis_tready
);
    parameter PTR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem[DEPTH];
    logic [PTR_WIDTH:0] wrPtr, wrPtrNext;
    logic [PTR_WIDTH:0] rdPtr, rdPtrNext;

    // Assign next pointer value
    always_comb begin
        wrPtrNext = wrPtr;
        rdPtrNext = rdPtr;
        // writePtr += 1 only if S_AXIS tready and tvalid handsake asserted
        if (s_axis_tready && s_axis_tvalid) begin
            wrPtrNext = wrPtr + 1;
        end
        // readPtr += 1 only if M_AXIS tready and tvalid handsake asserted
        if (m_axis_tready && m_axis_tvalid) begin
            rdPtrNext = rdPtr + 1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wrPtr <= '0;
            rdPtr <= '0;
            // Initialize FIFO memory
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
        end else begin
            wrPtr <= wrPtrNext;
            rdPtr <= rdPtrNext;
        end

        mem[wrPtr[PTR_WIDTH-1:0]] <= s_axis_tdata;
    end

    assign m_axis_tdata = mem[rdPtr[PTR_WIDTH-1:0]];

    // Check full, includes a wrapping check on pointers
    assign empty = (wrPtr[PTR_WIDTH] == rdPtr[PTR_WIDTH]) && (wrPtr[PTR_WIDTH-1:0] == rdPtr[PTR_WIDTH-1:0]);
    assign full  = (wrPtr[PTR_WIDTH] != rdPtr[PTR_WIDTH]) && (wrPtr[PTR_WIDTH-1:0] == rdPtr[PTR_WIDTH-1:0]);
    
    // MASTER assign AXI T signals
    // M_TLAST
    assign m_axis_tlast = (rdPtrNext == wrPtr) && (rdPtrNext != rdPtr);
    // M_TVALID
    assign m_axis_tvalid = ~empty;

    // SLAVE assign AXI T signals
    assign s_axis_tready = ~full;


endmodule
