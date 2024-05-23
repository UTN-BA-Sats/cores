module FIFO
#(
    parameter ADDR_LENGTH = 8, WORD_LENGTH = 8
)
(
    input wire clk,
    input wire [WORD_LENGTH - 1 : 0] data_in,
    input wire data_in_valid,
    input wire ready_out,
    input wire reset,
    output reg [WORD_LENGTH - 1 : 0] data_out,
    output reg data_out_valid,
    output reg ready_in
);

reg read_en;
reg write_en;
wire full;
wire empty;

localparam IDLE_IN = 2'b00;
localparam READY_READ = 2'b01;
localparam READING_DATA = 2'b10;

localparam IDLE_OUT = 2'b00;
localparam OUTPUT_DATA = 2'b01;

localparam WAIT_STATE = 2'b11;

reg[1:0] state_in;
reg[1:0] next_state_in;

reg[1:0] state_out;
reg[1:0] next_state_out;

wire[WORD_LENGTH - 1 : 0] internal_data_out;

FIFO_internal #(ADDR_LENGTH, WORD_LENGTH) fifo_internal (
    .clk(clk),
    .data_in(data_in),
    .read_en(read_en),
    .write_en(write_en),
    .reset(reset),
    .data_out(internal_data_out),
    .full(full),
    .empty(empty)
);

always @(*) begin
// Input handshake next state logic
    case(state_in)
        IDLE_IN : begin
            if(full == 1'b0) begin
                next_state_in = READY_READ;
            end else begin
                next_state_in = IDLE_IN;
            end
        end

        READY_READ : begin
            if(data_in_valid == 1'b1) begin
                next_state_in = READING_DATA;
            end else begin
                next_state_in = READY_READ;
            end
        end

        READING_DATA : begin
            if(data_in_valid == 1'b0) begin
                next_state_in = IDLE_IN;
            end else begin
                next_state_in = WAIT_STATE;
            end
        end

        WAIT_STATE : begin
            if(data_in_valid == 1'b0) begin
                if(full == 1'b0) begin
                    next_state_in = READY_READ;
                end else begin
                    next_state_in = IDLE_IN;
                end
            end else begin
                next_state_in = WAIT_STATE;
            end
        end

        default : next_state_in = IDLE_IN;
    endcase

    if(next_state_in == READING_DATA) begin
        write_en = 1'b1;
    end else begin
        write_en = 1'b0;
    end

// Output handshake next state logic
    case(state_out)
        IDLE_OUT : begin
            if(ready_out == 1'b1 && empty == 1'b0) begin
                next_state_out = OUTPUT_DATA;
            end else begin
                next_state_out = IDLE_OUT;
            end
        end

        OUTPUT_DATA : begin
            if(ready_out == 1'b0) begin
                next_state_out = IDLE_OUT;
            end else begin
                next_state_out = WAIT_STATE;
            end
        end

        WAIT_STATE : begin
            if(ready_out == 1'b0) begin
                next_state_out = IDLE_OUT;
            end else begin
                next_state_out = WAIT_STATE;
            end
        end

        default : next_state_out = IDLE_OUT;
    endcase

    if(next_state_out == OUTPUT_DATA) begin
        read_en = 1'b1;
    end else begin
        read_en = 1'b0;
    end
end

// Output signals logic
always @(*) begin
    if(state_in == READY_READ) begin
        ready_in = 1'b1;
    end else begin
        ready_in = 1'b0;
    end

    if(state_out == OUTPUT_DATA || state_out == WAIT_STATE) begin
        data_out_valid = 1'b1;
    end else begin
        data_out_valid = 1'b0;
    end
end

always @(posedge clk) begin
    if(reset == 1) begin
        state_in <= IDLE_IN;
        state_out <= IDLE_OUT;
    end else begin
        state_in <= next_state_in;
        state_out <= next_state_out;

        if(empty == 1'b0) begin
            data_out <= internal_data_out;
        end
    end
end

endmodule
