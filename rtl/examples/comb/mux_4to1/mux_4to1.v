module mux_4to1 (
    input [3:0] i_E,
    input [1:0] i_Sel,
    output [3:0] o_I0,
    output [3:0] o_I1,
    output [3:0] o_I2,
    output [3:0] o_I3
);

assign o_I0 = (i_Sel == 2'b00) ? i_E : 0;
assign o_I1 = (i_Sel == 2'b01) ? i_E : 0;
assign o_I2 = (i_Sel == 2'b10) ? i_E : 0;
assign o_I3 = (i_Sel == 2'b11) ? i_E : 0;

endmodule