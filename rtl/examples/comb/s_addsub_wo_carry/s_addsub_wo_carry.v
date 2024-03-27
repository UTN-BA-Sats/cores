module s_addsub_wo_carry #(
    parameter N = 4
)(
    input signed [N-1:0] i_A,
    input signed [N-1:0] i_B,
    input i_Op,
    output [N-1:0] o_Z
);

assign o_Z = (i_Op == 0) ? (i_A + i_B) : (i_A - i_B);

endmodule