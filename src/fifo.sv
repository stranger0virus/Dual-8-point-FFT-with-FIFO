`timescale 1ns/10ps

module fifo #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 5 // 2^4 = 16 entries
)(
    input logic clk,
    input logic rst,
    input logic write_en,
    input logic read_en,
    input logic signed [DATA_WIDTH-1:0] data_in,
    output logic signed [DATA_WIDTH-1:0] data_out,
    output logic full,
    output logic empty
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;

    wire [ADDR_WIDTH:0] wr_ptr_next = wr_ptr + write_en;
    wire [ADDR_WIDTH:0] rd_ptr_next = rd_ptr + read_en;

	always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            full   <= 0;
            empty  <= 1;
        end

        else begin

        // Write
        if (write_en && !full) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_in;
                wr_ptr <= wr_ptr_next;
        end

        // Read
        if (read_en && !empty) begin
                data_out <= mem[rd_ptr[ADDR_WIDTH-1:0]];
          	  	rd_ptr <= rd_ptr_next;
        end

        full  <= (wr_ptr_next[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH])
                  && (wr_ptr_next[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
        empty <= (wr_ptr == rd_ptr);

     end
   end
endmodule



