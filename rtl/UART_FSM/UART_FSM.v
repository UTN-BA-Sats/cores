module UART_FSM #(
    parameter DATA_DEPTH = 8,
    parameter DATA_SENSOR0 = 97,
    parameter DATA_SENSOR1 = 98,
    parameter DATA_SENSOR2 = 99,
    parameter DATA_SENSOR3 = 100,
    parameter DATA_SENSOR4 = 101,
    parameter DATA_SENSOR5 = 102,
    parameter DATA_SENSOR6 = 103,
    parameter DATA_SENSOR7 = 104,
    parameter FSM_SENSOR0 =  105,
    parameter FSM_SENSOR1 =  106,
    parameter FSM_SENSOR2 =  107,
    parameter FSM_SENSOR3 =  108,
    parameter FSM_SENSOR4 =  109,
    parameter FSM_SENSOR5 =  110,
    parameter FSM_SENSOR6 =  111,
    parameter FSM_SENSOR7 =  112,
    parameter FIFO_EMPTY_ERROR_CODE = 85,
    parameter CANT_SENSORES = 8
) (
    input i_clk,
    input i_rst,

    input [DATA_DEPTH-1:0] i_uart_recived_data,
    input i_uart_recived_valid,
    output reg o_uart_recived_data_ready,

    output reg [DATA_DEPTH-1:0] o_uart_send_data,
    output reg o_uart_send_valid,
    input i_uart_send_data_ready,

    output reg [CANT_SENSORES-1:0] o_request_data,
    input [CANT_SENSORES-1:0] i_data_ready,

    input i_fifo0_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo0_data_out,
    input i_fifo0_empty,
    output reg o_fifo0_data_out_extracted,
    output reg o_fsm0_rst,

    input i_fifo1_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo1_data_out,
    input i_fifo1_empty,
    output reg o_fifo1_data_out_extracted,
    output reg o_fsm1_rst,

    input i_fifo2_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo2_data_out,
    input i_fifo2_empty,
    output reg o_fifo2_data_out_extracted,
    output reg o_fsm2_rst,

    input i_fifo3_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo3_data_out,
    input i_fifo3_empty,
    output reg o_fifo3_data_out_extracted,
    output reg o_fsm3_rst,

    input i_fifo4_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo4_data_out,
    input i_fifo4_empty,
    output reg o_fifo4_data_out_extracted,
    output reg o_fsm4_rst,

    input i_fifo5_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo5_data_out,
    input i_fifo5_empty,
    output reg o_fifo5_data_out_extracted,
    output reg o_fsm5_rst,

    input i_fifo6_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo6_data_out,
    input i_fifo6_empty,
    output reg o_fifo6_data_out_extracted,
    output reg o_fsm6_rst,

    input i_fifo7_data_out_valid_to_extract,
    input [DATA_DEPTH-1:0] i_fifo7_data_out,
    input i_fifo7_empty,
    output reg o_fifo7_data_out_extracted,
    output reg o_fsm7_rst
);

//Estados
localparam RESET=0, WAITING_UART_VALID=1,WAITING_MESSAGE=2,READ_MESSAGE=3,SEND_INFO=4,WAIT_SEND_INFO=5,SEND_DECIMAL_INFO=6,REQUEST_DATA=7,REQUEST_DATA_WAIT=8,REQUEST_DATA_WAIT_IDLE=9;

//Registro para los estados
reg [3:0] r_state;
reg [3:0] r_nstate;

//Registros
reg [CANT_SENSORES-1:0] r_data_ready_prev_val;
reg [CANT_SENSORES-1:0] r_data_ready;
reg r_uart_recived_valid;
reg r_uart_recived_valid_prev;
reg r_decimal_data;
reg r_decimal_data_prev;
reg [DATA_DEPTH-1:0] r_uart_recived_data;
reg [DATA_DEPTH-1:0] r_uart_send_data;

always @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
            r_uart_recived_valid <= 1'b1;
            r_uart_recived_valid_prev <= 1'b1;
            r_state = WAITING_UART_VALID;
            r_decimal_data <= 1'b0;
            r_decimal_data_prev <= 1'b0;
            r_uart_recived_data <= 0;
            r_uart_send_data <= 0;
            r_data_ready_prev_val <= 0;
            r_data_ready <= 0;
            o_request_data <= 0;
    end
    else begin
    
        r_uart_recived_valid <= i_uart_recived_valid;
        r_data_ready <= i_data_ready;

        case (r_state)
            WAITING_UART_VALID: begin

                if(((r_uart_recived_valid==1'b0) && (r_uart_recived_valid_prev==1'b1)) || (r_decimal_data==1'b1)) begin
                    r_state = WAITING_MESSAGE;
                end            

                o_uart_send_valid <= 0;
                o_uart_send_data <= 0;
                o_uart_recived_data_ready <= 0;
                o_fsm0_rst <= 1'b0;
                o_fifo0_data_out_extracted <= 1'b0;
                o_fsm1_rst <= 1'b0;
                o_fifo1_data_out_extracted <= 1'b0;
                o_fsm2_rst <= 1'b0;
                o_fifo2_data_out_extracted <= 1'b0;
                o_fsm3_rst <= 1'b0;
                o_fifo3_data_out_extracted <= 1'b0;
                o_fsm4_rst <= 1'b0;
                o_fifo4_data_out_extracted <= 1'b0;
                o_fsm5_rst <= 1'b0;
                o_fifo5_data_out_extracted <= 1'b0;
                o_fsm6_rst <= 1'b0;
                o_fifo6_data_out_extracted <= 1'b0;
                o_fsm7_rst <= 1'b0;
                o_fifo7_data_out_extracted <= 1'b0;

            end
            WAITING_MESSAGE: begin

                if(((r_uart_recived_valid==1'b1) && (r_uart_recived_valid_prev==1'b0) || (r_decimal_data == 1'b1))) begin
                    if(r_decimal_data == 1'b1) begin
                        r_state = READ_MESSAGE;
                    end
                    else begin
                        r_state = REQUEST_DATA;
                    end
                end

            end
            REQUEST_DATA: begin

                case (i_uart_recived_data)
                    DATA_SENSOR0: begin
                        o_request_data[0] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    DATA_SENSOR1: begin
                        o_request_data[1] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    DATA_SENSOR2: begin
                        o_request_data[2] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    DATA_SENSOR3: begin
                        o_request_data[3] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    DATA_SENSOR4: begin
                        o_request_data[4] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    DATA_SENSOR5: begin
                        o_request_data[5] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    DATA_SENSOR6: begin
                        o_request_data[6] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    DATA_SENSOR7: begin
                        o_request_data[7] <= 1'b1;
                        r_state = REQUEST_DATA_WAIT_IDLE;
                    end
                    default: begin
                        r_state = READ_MESSAGE;
                    end
                endcase

            end
            REQUEST_DATA_WAIT_IDLE: begin
                case (i_uart_recived_data)
                    DATA_SENSOR0: begin
                        if(r_data_ready[0]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    DATA_SENSOR1: begin
                        if(r_data_ready[1]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    DATA_SENSOR2: begin
                        if(r_data_ready[2]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    DATA_SENSOR3: begin
                        if(r_data_ready[3]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    DATA_SENSOR4: begin
                        if(r_data_ready[4]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    DATA_SENSOR5: begin
                        if(r_data_ready[5]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    DATA_SENSOR6: begin
                        if(r_data_ready[6]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    DATA_SENSOR7: begin
                        if(r_data_ready[7]==1'b0) r_state = REQUEST_DATA_WAIT;
                    end
                    default: begin
                        r_state = READ_MESSAGE;
                    end
                endcase
            end
            REQUEST_DATA_WAIT: begin
                case (i_uart_recived_data)
                    DATA_SENSOR0: begin
                        if(r_data_ready[0]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[0] <= 0;
                    end
                    DATA_SENSOR1: begin
                        if(r_data_ready[1]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[1] <= 0;
                    end
                    DATA_SENSOR2: begin
                        if(r_data_ready[2]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[2] <= 0;
                    end
                    DATA_SENSOR3: begin
                        if(r_data_ready[3]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[3] <= 0;
                    end
                    DATA_SENSOR4: begin
                        if(r_data_ready[4]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[4] <= 0;
                    end
                    DATA_SENSOR5: begin
                        if(r_data_ready[5]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[5] <= 0;
                    end
                    DATA_SENSOR6: begin
                        if(r_data_ready[6]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[6] <= 0;
                    end
                    DATA_SENSOR7: begin
                        if(r_data_ready[7]==1'b1) r_state = READ_MESSAGE;
                        o_request_data[7] <= 0;
                    end
                    default: begin
                        r_state = READ_MESSAGE;
                    end
                endcase
                
            end
            READ_MESSAGE: begin

                case (i_uart_recived_data)
                    DATA_SENSOR0: begin

                        if(i_fifo0_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo0_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo0_data_out;
                            end

                            o_fifo0_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end

                    end
                    DATA_SENSOR1: begin

                        if(i_fifo1_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo1_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo1_data_out;
                            end

                            o_fifo1_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end
                    end
                    DATA_SENSOR2: begin

                        if(i_fifo2_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo2_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo2_data_out;
                            end

                            o_fifo2_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end
                    end
                    DATA_SENSOR3: begin

                        if(i_fifo3_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo3_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo3_data_out;
                            end

                            o_fifo3_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end
                    end
                    DATA_SENSOR4: begin

                        if(i_fifo4_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo4_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo4_data_out;
                            end

                            o_fifo4_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end
                    end
                    DATA_SENSOR5: begin

                        if(i_fifo5_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo5_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo5_data_out;
                            end

                            o_fifo5_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end
                    end
                    DATA_SENSOR6: begin

                        if(i_fifo6_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo6_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo6_data_out;
                            end

                            o_fifo6_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end
                    end
                    DATA_SENSOR7: begin

                        if(i_fifo7_empty==1'b0 || r_decimal_data==1'b1) begin
                            if(i_fifo7_data_out_valid_to_extract==1'b1) begin
                                r_state = SEND_INFO;
                                r_uart_send_data <= i_fifo7_data_out;
                            end

                            o_fifo7_data_out_extracted <= 1;
                        end
                        else begin
                            r_state = SEND_INFO;
                            r_uart_send_data <= FIFO_EMPTY_ERROR_CODE;
                        end
                    end
                    FSM_SENSOR0: begin
                        o_fsm0_rst <= 1;
                    end
                    FSM_SENSOR1: begin
                        o_fsm1_rst <= 1;
                    end
                    FSM_SENSOR2: begin
                        o_fsm2_rst <= 1;
                    end
                    FSM_SENSOR3: begin
                        o_fsm3_rst <= 1;
                    end
                    FSM_SENSOR4: begin
                        o_fsm4_rst <= 1;
                    end
                    FSM_SENSOR5: begin
                        o_fsm5_rst <= 1;
                    end
                    FSM_SENSOR6: begin
                        o_fsm6_rst <= 1;
                    end
                    FSM_SENSOR7: begin
                        o_fsm7_rst <= 1;
                    end
                    default: begin
                        r_state = WAITING_UART_VALID;
                    end
                endcase

            end
            SEND_INFO: begin

                if(i_uart_recived_data>=DATA_SENSOR0 && i_uart_recived_data<=DATA_SENSOR7) r_state = WAIT_SEND_INFO;
                else r_state = WAITING_UART_VALID;

                case (i_uart_recived_data)
                    DATA_SENSOR0: begin
                        o_fifo0_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    DATA_SENSOR1: begin
                        o_fifo1_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    DATA_SENSOR2: begin
                        o_fifo2_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    DATA_SENSOR3: begin
                        o_fifo3_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    DATA_SENSOR4: begin
                        o_fifo4_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    DATA_SENSOR5: begin
                        o_fifo5_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    DATA_SENSOR6: begin
                        o_fifo6_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    DATA_SENSOR7: begin
                        o_fifo7_data_out_extracted <= 0;
                        o_uart_send_data <= r_uart_send_data;
                        o_uart_send_valid <= 1;
                    end
                    FSM_SENSOR0: begin
                        o_fsm0_rst <= 0;
                    end
                    FSM_SENSOR1: begin
                        o_fsm1_rst <= 0;
                    end
                    FSM_SENSOR2: begin
                        o_fsm2_rst <= 0;
                    end
                    FSM_SENSOR3: begin
                        o_fsm3_rst <= 0;
                    end
                    FSM_SENSOR4: begin
                        o_fsm4_rst <= 0;
                    end
                    FSM_SENSOR5: begin
                        o_fsm5_rst <= 0;
                    end
                    FSM_SENSOR6: begin
                        o_fsm6_rst <= 0;
                    end
                    FSM_SENSOR7: begin
                        o_fsm7_rst <= 0;
                    end
                endcase

            end
            WAIT_SEND_INFO: begin

                if(r_uart_send_data!=FIFO_EMPTY_ERROR_CODE) r_state = SEND_DECIMAL_INFO;
                else begin
                    r_state = WAITING_UART_VALID;
                    r_decimal_data <= 1'b0;
                end

                o_uart_send_valid <= 0;                    
                
            end
            SEND_DECIMAL_INFO: begin

                if(i_uart_send_data_ready==1'b1) begin
                    r_decimal_data = ~r_decimal_data_prev;
                    r_state = WAITING_UART_VALID;
                end
            end
            RESET: begin
                r_state = WAITING_UART_VALID;

                o_uart_send_valid <= 1'b0;
                o_uart_send_data <= 0;
                o_uart_recived_data_ready <= 1'b0;
                o_fsm0_rst <= 1'b0;
                o_fifo0_data_out_extracted <= 1'b0;
                o_fsm1_rst <= 1'b0;
                o_fifo1_data_out_extracted <= 1'b0;
                o_fsm2_rst <= 1'b0;
                o_fifo2_data_out_extracted <= 1'b0;
                o_fsm3_rst <= 1'b0;
                o_fifo3_data_out_extracted <= 1'b0;
                o_fsm4_rst <= 1'b0;
                o_fifo4_data_out_extracted <= 1'b0;
                o_fsm5_rst <= 1'b0;
                o_fifo5_data_out_extracted <= 1'b0;
                o_fsm6_rst <= 1'b0;
                o_fifo6_data_out_extracted <= 1'b0;
                o_fsm7_rst <= 1'b0;
                o_fifo7_data_out_extracted <= 1'b0;
            end
            default: begin
                r_state = WAITING_UART_VALID;

                o_uart_send_valid <= 1'b0;
                o_uart_send_data <= 0;
                o_uart_recived_data_ready <= 1'b0;
                o_fsm0_rst <= 1'b0;
                o_fifo0_data_out_extracted <= 1'b0;
                o_fsm1_rst <= 1'b0;
                o_fifo1_data_out_extracted <= 1'b0;
                o_fsm2_rst <= 1'b0;
                o_fifo2_data_out_extracted <= 1'b0;
                o_fsm3_rst <= 1'b0;
                o_fifo3_data_out_extracted <= 1'b0;
                o_fsm4_rst <= 1'b0;
                o_fifo4_data_out_extracted <= 1'b0;
                o_fsm5_rst <= 1'b0;
                o_fifo5_data_out_extracted <= 1'b0;
                o_fsm6_rst <= 1'b0;
                o_fifo6_data_out_extracted <= 1'b0;
                o_fsm7_rst <= 1'b0;
                o_fifo7_data_out_extracted <= 1'b0;
            end
        endcase

        r_decimal_data_prev <= r_decimal_data;
        r_uart_recived_valid_prev <= r_uart_recived_valid;
        r_data_ready_prev_val <= r_data_ready;

    end

end


endmodule