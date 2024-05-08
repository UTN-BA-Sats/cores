module uart_tx (
    
    // input stream
    input [8-1:0] i_data,
    input i_valid,
    output reg o_ready,

    // control signal
    input i_clk,
    input i_rst,

    input i_txpulse,
    output reg o_txd

);

localparam STATE_BITS = 3;
localparam  S_IDLE =        'd0,
            S_SYNC =        'd1,
            S_TXSTART =     'd2,
            S_TXSEND =      'd3,
            S_TXSTOP =      'd4
;

wire w_baudclk;
wire w_intrst;

reg [3-1:0] r_bitcnt;
reg [3-1:0] r_nextcnt;
reg [8-1:0] r_txdata;
reg [STATE_BITS-1:0] r_actstate;

assign w_intrst = i_rst;

always @(posedge i_clk or posedge w_intrst) begin
    
    if (w_intrst == 1'b1) begin
        
        r_actstate <= S_IDLE;
        r_bitcnt <= 'b0;
        r_txdata <= 'b0;
        o_ready <= 'b0;
    
    end else begin

        o_txd <= 1'b1;
        o_ready <= 1'b0;

        case (r_actstate)

            S_IDLE: begin
                o_ready <= 1'b1;
                r_txdata <= 'b0;
                if (i_valid == 1'b1) begin
                    r_txdata <= i_data;
                    r_actstate <= S_SYNC;
                    o_ready <= 1'b0;
                end
            end

            S_SYNC: begin
                if (i_txpulse == 1'b1) begin
                    r_bitcnt <= 8'd7;
                    r_actstate <= S_TXSTART;
                end
            end

            S_TXSTART: begin
                o_txd <= 1'b0;
                if (i_txpulse == 1'b1) begin
                    r_actstate <= S_TXSEND;
                end
            end

            S_TXSEND: begin
                
                o_txd <= r_txdata[r_bitcnt];
                if (i_txpulse == 1'b1) begin
                    if (r_bitcnt > 8'd0) begin
                        r_bitcnt <= r_bitcnt - 1;
                    end else begin
                        r_actstate <= S_TXSTOP;
                    end
                end

            end

            S_TXSTOP: begin
                if (i_txpulse == 1'b1) begin
                    r_actstate <= S_IDLE;
                end
            end

            default: begin
                r_actstate <= S_IDLE;
            end

        endcase 

    end

end
    
endmodule