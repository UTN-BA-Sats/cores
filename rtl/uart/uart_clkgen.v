module uart_clkgen #(
    parameter DIV_BITS = 10
) (
    input i_clk,
    input i_rst,

    input [DIV_BITS-1:0] i_div,

    input i_rxsync,
    
    output reg o_txpulse,
    output reg o_rxpulse
);

reg [DIV_BITS-1:0] r_txclk;
reg [DIV_BITS-1:0] r_rxclk;

//sobresampleo 16x (por la cantidad de bits)
reg [4-1:0] r_txcntr;
reg [4-1:0] r_rxcntr;

reg [DIV_BITS-1:0] r_div;
    
always @(posedge i_rst or posedge i_clk) begin
    
    if (i_rst == 1'b1) begin
        
       r_div <= 'b0;
       r_txclk <= 'b0;
       r_rxclk <= 'b0;
       r_txcntr <= 'b0;
       r_rxcntr <= 'b0;

    end else begin
        
        r_div <= i_div;
        o_rxpulse <= 1'b0;
        o_txpulse <= 1'b0;

        if (i_rxsync == 1'b1) begin
            r_rxcntr <= 'b0;
            r_rxclk <= 'b0;
        end

        if (r_div != 'b0) begin

            r_txclk <= r_txclk + 1;
            r_rxclk <= r_rxclk + 1;

            if (r_txclk >= r_div) begin
                r_txclk <= 'b0;
                
                if (r_txcntr >= 4'd15)
                    o_txpulse <= 1'b1;

                r_txcntr <= r_txcntr + 1;

            end

            if (r_rxclk >= r_div) begin
                r_rxclk <= 'b0;
                
                if (r_rxcntr >= 4'd5 && r_rxcntr <= 4'd7)
                    o_rxpulse <= 1'b1;

                r_rxcntr <= r_rxcntr + 1;

            end

        end

    end

end


endmodule