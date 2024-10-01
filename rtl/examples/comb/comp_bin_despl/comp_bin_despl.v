/*brief: Este módulo compara dos números binarios de N bits y proporciona 
*señales que indican si uno es mayor, menor o igual al otro. Permite un 
*desplazamiento opcional de los bits de entrada bajo la señal de control i_Ctrl.
*/
module comp_bin_despl #(
  parameter N = 8
) (
  input  [N-1:0] i_A,
  input  [N-1:0] i_B,
  input          i_Clk,
  input          i_Ctrl,
  output reg     o_Mayor,
  output reg     o_Igual,
  output reg     o_Menor
);

  reg r_AgtB, r_AeqB;
  reg [N-1:0] r_A, r_B;

  always @(posedge i_Clk) begin
	  o_Mayor  = r_AgtB;
	  o_Igual  = r_AeqB;
	  o_Menor  = ~r_AgtB & ~r_AeqB;

	  r_A       = (i_Ctrl) ? ~(i_A[N-1]) & i_A[N-2:0] : i_A;
	  r_B       = (i_Ctrl) ? ~(i_B[N-1]) & i_B[N-2:0] : i_B;

	  r_AgtB    = $unsigned(r_A) > $unsigned(r_B);
	  r_AeqB    = $unsigned(r_A) == $unsigned(r_B);
  end
endmodule