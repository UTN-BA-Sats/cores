module comparator #(
    parameter N = 8
) (
    input wire unsigned [N-1:0] i_A,
    input wire unsigned [N-1:0] i_B,
    output reg o_Mayor,
    output reg o_Menor,
    output reg o_Igual
);

wire [2:0] w_out;

assign w_out = (i_A > i_B) ? 3'b100 : ((i_A < i_B) ? 3'b010 : 3'b001);
assign o_Mayor = w_out[2];
assign o_Menor = w_out[1];
assign o_Igual = w_out[0];

endmodule