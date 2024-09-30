module uart_rx (
    //stream interface
    output reg [8-1:0] o_data,
    output reg o_valid,
    input i_ready,

    //control signals
    input i_clk,
    input i_rxd,
    input i_rst,

    input i_rxpulse,
    
    output reg o_err,
    output reg o_rxsync
);

localparam STATE_BITS = 3;
localparam  S_IDLE =        'd0,
            S_VSTART =      'd1,
            S_RECV =        'd2,
            S_VSTOP =       'd3,
            S_RXERR =       'd4;

reg [8-1:0] r_data_bits;
reg [3-1:0] r_data_counter;
reg [3-1:0] r_rxd_meta;
reg [STATE_BITS-1:0] r_state;
reg [3-1:0] r_rxd_samples;
reg [2-1:0] r_rxd_sample_counter;

reg r_rxd_valid_flag;
reg r_rxd_validated;

wire w_rxd;

assign w_rxd = r_rxd_meta[2];

always @(posedge i_clk or posedge i_rst) begin

    o_rxsync = 1'b0;
    r_rxd_validated = 1'b0;

    if(i_rst == 1'b1) begin

        r_state = S_IDLE;

    end else begin

        /* Metastability fix of i_rxd */
        r_rxd_meta = r_rxd_meta << 1;
        r_rxd_meta[0] = i_rxd;

        /* rxd signal sampler */
        if (r_state == S_VSTART || r_state == S_RECV || r_state == S_VSTOP) begin
            
            if (i_rxpulse == 1'b1) begin

                r_rxd_samples[r_rxd_sample_counter] = w_rxd;

                if(r_rxd_sample_counter < 2'd2) begin

                    r_rxd_sample_counter = r_rxd_sample_counter + 1;

                end else begin

                    r_rxd_sample_counter = 2'd0;
                    r_rxd_valid_flag = 2'd1;

                    case (r_rxd_samples)
                        
                        3'd0,
                        3'd1,
                        3'd2,
                        3'd4: r_rxd_validated = 1'b0;
                        
                        default: r_rxd_validated = 1'b1;

                    endcase

                end

            end

        end

        /* State machine */
        case (r_state)
            
            S_IDLE: begin
                
                if (w_rxd == 1'b0) begin

                    r_state = S_VSTART;
                    r_rxd_samples = 'b0;
                    r_rxd_sample_counter = 'b0;
                    r_rxd_valid_flag = 1'b0;
                    r_data_bits = 'b0;
                    r_data_counter = 'b0;
                    o_rxsync = 1'b1;
                    o_valid = 1'b0;
                    o_data = 'b0;

                end

            end

            S_VSTART: begin

                if (r_rxd_valid_flag == 1'b1) begin
                    
                    r_rxd_valid_flag = 1'b0;

                    if(r_rxd_validated == 1'b0) begin
                        
                        r_state = S_RECV;

                    end else begin

                        r_state = S_RXERR;

                    end

                end

            end

            S_RECV: begin

                if (r_rxd_valid_flag == 1'b1) begin
                    
                    r_rxd_valid_flag = 1'b0;

                    // UART is LSB first
                    r_data_bits = r_data_bits >> 1;
                    r_data_bits[7] = r_rxd_validated;

                    if (r_data_counter == 3'd7) begin
                        r_state = S_VSTOP;
                    end

                    r_data_counter = r_data_counter + 1;

                end

            end

            S_VSTOP: begin

                if (r_rxd_valid_flag == 1'b1) begin
                    
                    r_rxd_valid_flag = 1'b0;

                    if(r_rxd_validated == 1'b1) begin
                        
                        r_state = S_IDLE;
                        o_data = r_data_bits;
                        o_valid = 1'b1;

                    end else begin

                        r_state = S_RXERR;

                    end

                end

            end

            S_RXERR: begin
                
                o_err = 1'b1;
                r_state = S_IDLE;

            end

            default: r_state = S_IDLE;

        endcase

    end
    
end
    
endmodule