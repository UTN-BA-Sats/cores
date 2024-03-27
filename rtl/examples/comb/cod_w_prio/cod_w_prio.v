module cod_w_prio (
    input i_I0,
    input i_I1,
    input i_I2,
    input i_I3,
    output reg [2-1:0] o_C,
    output reg o_G
);

assign o_C = (i_I3 == 1) ? 2'b11 : ((i_I2 == 1) ? 2'b10 : ((i_I1 == 1) ? 2'b01 : 2'b00));
assign o_G = ~(i_I0 | i_I1 | i_I2 | i_I3);


endmodule