// This module is a custom AXIS FIFO to patch the lack of support
// For using FINN stiched IP with Xilinx "vinilla DMA"

// It implements a dumb FIFO except TLAST is only implemented on the MASTER interface.

// Made for the "PyTorch to FPGA" Course

module custom_fifo #(
    parameter DEPTH = 8,
    parameter IN_DATA_WIDTH = 8,
    parameter OUT_DATA_WIDTH = 32
) (
    // AXIS
    input wire clk,
    input wire rst_n,

    // (SLAVE) AI Model interface
    input wire s_axis_tvalid,
    input wire [IN_DATA_WIDTH-1:0] s_axis_tdata,
    output wire s_axis_tready,

    // (MASTER) DMA Interface
    output wire m_axis_tvalid,
    output wire [OUT_DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tlast,
    input wire m_axis_tready
);
    localparam PTR_WIDTH = $clog2(DEPTH);

    logic [IN_DATA_WIDTH-1:0] mem[DEPTH];
    logic [PTR_WIDTH:0] wr_ptr;
    logic [PTR_WIDTH:0] rd_ptr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            // Initialize FIFO memory
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                mem[wr_ptr[PTR_WIDTH-1:0]] <= s_axis_tdata;
                wr_ptr <= wr_ptr + 1;
            end
            if (m_axis_tready && m_axis_tvalid) begin
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

    // Fills the width difference with 0, this is to avoid weird DMA behavior that i DO NOT want to deal with
    assign m_axis_tdata = {{(OUT_DATA_WIDTH-IN_DATA_WIDTH){1'b0}}, mem[rd_ptr[PTR_WIDTH-1:0]]};

    // Check full, includes a wrapping check on pointers
    assign empty = (wr_ptr[PTR_WIDTH] == rd_ptr[PTR_WIDTH]) && (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);
    assign full  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) && (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);
    
    // MASTER assign AXI T signals
    // M_TLAST
    assign m_axis_tlast = (m_axis_tready && m_axis_tvalid) && ((rd_ptr + 1'b1) == wr_ptr);
    // M_TVALID
    assign m_axis_tvalid = ~empty;

    // SLAVE assign AXI T signals
    assign s_axis_tready = ~full;


endmodule
