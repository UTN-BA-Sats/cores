/*brief: returns inputs expanded to 8 bits*/
module sign_expander(input clk, input [3:0] i_A, output reg [7:0] o_Z);

  always @(posedge clk) begin
    o_Z[3:0] <= i_A;
    o_Z[7:4] <= {4{i_A[3]}};
  end

endmodule