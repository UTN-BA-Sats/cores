module bin2gray #(
    parameter N = 8
) (
    input [N-1:0] i_Gray,
    output reg [N-1:0] o_Bin
);

wire [N-1:0] w_aux;

assign w_aux[N-1] = i_Gray[N-1];
assign w_aux[N-2:0] = i_Gray[N-2:0] ^ w_aux[N-1:1];
assign o_Bin = w_aux;

endmodule