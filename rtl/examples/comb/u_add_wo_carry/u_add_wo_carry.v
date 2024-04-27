/*brief: module that returns the sum of the inputs without the carry bit*/
module u_add_wo_carry(input clk, input [4-1:0] i_A,input [4-1:0] i_B, output reg [4-1:0] o_Z);
	
	always@(posedge clk) begin
		o_Z <= i_A + i_B;
	end

endmodule