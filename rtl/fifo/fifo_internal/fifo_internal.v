module FIFO_internal
#(
    parameter ADDR_LENGTH = 8, WORD_LENGTH = 8
)
(
    input wire clk,
    input wire [WORD_LENGTH - 1 : 0] data_in,
    input wire read_en,
    input wire write_en,
    input wire reset,
    output wire [WORD_LENGTH - 1 : 0] data_out,
    output wire full,
    output wire empty
);

reg [ADDR_LENGTH - 1 : 0] w_addr;
reg [ADDR_LENGTH - 1 : 0] r_addr;

wire [ADDR_LENGTH - 1 : 0] next_r_addr;
wire [ADDR_LENGTH - 1 : 0] next_w_addr;

wire aux_write_en;

assign next_r_addr = r_addr + 1;
assign next_w_addr = w_addr + 1;

assign empty = (w_addr == r_addr);
assign full = (next_w_addr == r_addr);

assign aux_write_en = write_en & ~full;

RAM_DUALPORT #(ADDR_LENGTH, WORD_LENGTH) memory (
    .r_clk(clk),
    .w_clk(clk),
    .write_en(aux_write_en),
    .w_addr(w_addr),
    .r_addr(r_addr),
    .data_in(data_in),
    .data_out(data_out)
);

always @(posedge clk) begin
    if(reset == 1) begin
        r_addr <= {ADDR_LENGTH{1'b0}};
        w_addr <= {ADDR_LENGTH{1'b0}};
    end else begin
        if(read_en == 1'b1 && !empty) begin
            r_addr <= next_r_addr;
        end

        if(write_en == 1'b1 && !full) begin
            w_addr <= next_w_addr;
        end
    end
end

endmodule
