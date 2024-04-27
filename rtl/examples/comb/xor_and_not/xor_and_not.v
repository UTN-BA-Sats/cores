/*brief: module xor and not, returns the xor of the negated inputs
*/
module xor_and_not(input clk, input a, input b, output reg z);
always @(posedge clk) begin
	z = ~a ^ ~b; //^ Operador XOR
end
endmodule
