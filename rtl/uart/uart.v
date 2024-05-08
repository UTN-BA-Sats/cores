module uart #(
    parameter DIV_BITS = 10
) (
    input i_clk,
    input i_rst,

    input [DIV_BITS-1:0] i_div,

    input i_rxd,
    output o_txd,

    output [8-1:0] o_data,
    output o_valid,
    input i_ready,

    input [8-1:0] i_data,
    input i_valid,
    output o_ready,

    output o_rxerr

);

wire w_rxsync;

wire w_txpulse;
wire w_rxpulse;

uart_clkgen #(.DIV_BITS(DIV_BITS)) inst_clkgen (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_div(i_div),
    .i_rxsync(w_rxsync),
    .o_txpulse(w_txpulse),
    .o_rxpulse(w_rxpulse)
);

uart_rx inst_rx (
    .o_data(o_data),
    .o_valid(o_valid),
    .i_ready(i_ready),

    .i_clk(i_clk),
    .i_rst(i_rst),

    .i_rxd(i_rxd),

    .i_rxpulse(w_rxpulse),   
    
    .o_err(o_err),
    .o_rxsync(w_rxsync)
);

uart_tx inst_tx (
    .i_data(i_data),
    .i_valid(i_valid),
    .o_ready(o_ready),

    .i_clk(i_clk),
    .i_rst(i_rst),

    .o_txd(o_txd),

    .i_txpulse(w_txpulse)
);
    
endmodule