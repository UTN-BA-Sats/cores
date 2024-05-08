module uart_rx (
    //stream interface
    output reg [8-1:0] o_data,
    output o_valid,
    input i_ready,

    //control signals
    input i_clk,
    input i_rxd,
    input i_rst,

    input i_rxpulse,
    
    output reg o_err,
    output reg o_rxsync
);

localparam STATE_BITS = 2;
localparam  S_IDLE =        'd0,
            S_RXRECV =      'd1,
            S_RXEND =       'd2,
            S_RXERR =       'd3
;

reg [2-1:0] r_samplecntr;
reg [3-1:0] r_bitcntr;
reg r_bitsignal;
reg r_safebit;
reg r_valid;

reg r_actstate;
reg [8-1:0] r_rxdata;
reg [3-1:0] r_samplereg;

reg [2-1:0] r_rxdmeta;

reg r_ready;

assign o_valid = r_valid;

always @(posedge i_rst or posedge i_clk) begin

    if (i_rst == 1'b1) begin
        
        r_valid <= 'b0;
        r_actstate <= S_IDLE;
        r_samplecntr <= 2'b0;

    end else begin

        r_rxdmeta = r_rxdmeta << 1;
        r_rxdmeta[0] <= i_rxd;

        r_bitsignal <= 1'b0;
        o_rxsync <= 1'b0;

        if (i_rxpulse == 1'b1) begin
            
            r_samplereg[r_samplecntr] <= r_rxdmeta[1];
            
            if (r_samplecntr == 2'b0) begin
                
                case (r_samplereg)
                    
                    3'd0,
                    3'd1,
                    3'd2,
                    3'd4 : r_safebit <= 1'b0;

                    default : r_safebit <= 1'b1;

                endcase

                r_bitsignal <= 1'b1;

            end

            r_samplecntr <= r_samplecntr - 1;
        end

        if (r_bitsignal == 1'b1) begin

            o_err <= 1'b0;

            case (r_actstate)

                S_IDLE : begin
                    if (r_safebit == 1'b0) begin
                        r_actstate <= S_RXRECV;
                        o_rxsync <= 1'b1;
                        r_samplecntr <= 2'd2;
                        r_bitcntr <= 3'd7;
                        r_samplereg <= 'b0;
                        r_valid <= 1'b0;
                    end
                end

                S_RXRECV : begin

                    r_rxdata[r_bitcntr] <= r_safebit;

                    if (r_bitcntr == 3'b0) begin
                        r_actstate <= S_RXEND;
                    end

                    r_bitcntr <= r_bitcntr - 1;

                end

                S_RXEND : begin

                    if (r_safebit == 1'b1) begin
                        r_actstate <= S_IDLE;
                        o_data <= r_rxdata;
                        r_valid <= 1'b1;
                    end else begin
                        r_actstate <= S_RXERR;
                    end

                end

                S_RXERR : begin
                    r_actstate <= S_IDLE;
                    o_err <= 1'b1;
                end

                default : r_actstate <= S_IDLE;

            endcase

        end

    end

end
    
endmodule