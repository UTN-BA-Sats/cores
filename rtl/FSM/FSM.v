module FSM #(
     parameter DATA_DEPTH = 8,
     parameter NBYTES = 0,                        //El i2c_master empieza a contar desde el cero (0<=leer una vez)
     parameter ADDR_SLAVE_READ = 157,
     parameter ADDR_SLAVE_WRITE = 156,
     parameter CONFIG_REGISTER_WRITE = 9,         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
     parameter CONFIG_REGISTER_READ = 3,          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
     parameter CONFIG_REGISTER_DATA = 4,
     parameter SENSOR_DATA = 0,
     parameter SENSOR_DECIMAL_FRACTION_DATA = 21, //0x15
     parameter COUNTER_ACK_LIMIT = 25,
     parameter COUNTER_CONFIG_LIMIT = 25,
     parameter DATA_HAD_ERROR = 7                 //Según la datasheet, los valores decimales no pueden ocupar los 4 bits menos significativos. Por lo tanto, 0000 0111 (7) indicaria un error en la informacion decimal y entera previa a la decimal
)(
     input i_clk, 
     input i_rst,

     input i_force_rst,

     //control
     output reg o_start,
     input i_request_data,
     output reg o_data_ready, 
     
     //addr interface
     input i_addr_ready,
     output reg [DATA_DEPTH-1:0] o_addr_bits, 
     output reg o_addr_valid,

     //read parameters
     input i_nbytes_ready,
     output reg [DATA_DEPTH-1:0] o_nbytes_bits,
     output reg o_nbytes_valid,

     //read interface
     input [DATA_DEPTH-1:0] i_data_read_bits,
     input i_data_read_valid,
     output reg o_data_read_ready,

     //write interface
     input i_data_write_ready,                         
     output reg [DATA_DEPTH-1:0] o_data_write_bits,
     output reg o_data_write_valid,

     input i_nak,

     //FIFO

     input i_ready_in,
     output reg [DATA_DEPTH-1:0] o_data_in,
     output reg o_data_in_valid,

     input i_fifo_full,
     output reg o_err

);

//Registro para los estados
reg [3:0] r_state;
reg [3:0] r_nstate;

//Contadores
reg [7:0] r_counterAck;
reg [7:0] r_counterConfig;
reg [7:0] r_i2c_load_data_contr;
reg r_led_reset;

//Otros registros
reg r_prev_nak;
reg r_was_nak;
reg [7:0] r_prev_contr;
reg r_get_decimal_fraction;
reg r_prev_data_write_ready;

//Salidas
reg r_start;
reg r_data_ready;
reg [DATA_DEPTH-1:0] r_addr_bits;
reg r_addr_valid;
reg [DATA_DEPTH-1:0] r_nbytes_bits;
reg r_nbytes_valid;
reg r_data_read_ready;
reg [DATA_DEPTH-1:0] r_data_write_bits;
reg r_data_write_valid;
reg [DATA_DEPTH-1:0] r_data_in;
reg r_data_in_valid;
reg r_err;

//Estados
localparam ADDR=0, CONFIGUWRITE=1, CONFIGREAD=2, READING=3, NORESPOND=4, RESET=5, WAIT_REQUEST=6;

//Parametros locales

localparam  LOAD_ADDR =      'd0,
            LOAD_NBYTES =    'd1,
            ANALYSE_DATA =   'd2,
            LOAD_REG =       'd3,
            LOAD_DATA =      'd4,
            CHANGE_VALID =   'd5,
            SAVE_DATA =      'd6,
            WAIT_SAVE_DATA = 'd7,
            IDLE =           'd8,
            WAIT_STATE =     'd9
;

localparam NONE=0;

//Logica de las salidas
assign o_start = r_start;
assign o_addr_bits = r_addr_bits;
assign o_addr_valid = r_addr_valid;
assign o_nbytes_bits = r_nbytes_bits;
assign o_nbytes_valid = r_nbytes_valid;
assign o_data_read_ready = r_data_read_ready;
assign o_data_write_bits = r_data_write_bits;
assign o_data_write_valid = r_data_write_valid;
assign o_data_in = r_data_in;
assign o_data_in_valid = r_data_in_valid;
assign o_err = r_err | r_led_reset;
assign o_data_ready = r_data_ready;

//Logica de la maquina de estados

always @(posedge i_clk or posedge i_rst)
     begin
          if (i_rst) begin
               r_state <= RESET;
               r_nstate <= RESET;
               r_counterAck <= 0;
               r_counterConfig <= 0;
               r_i2c_load_data_contr <= IDLE;
               r_prev_nak <= 0;
               r_prev_contr <= IDLE;
               r_get_decimal_fraction <= 1'b0;
               r_led_reset <= 0;
               r_was_nak <= 0;
               r_data_ready <= 1;
          end
          else if (i_force_rst) begin
               r_state <= RESET;
               r_nstate <= RESET;
               r_counterAck <= 0;
               r_counterConfig <= 0;
               r_i2c_load_data_contr <= IDLE;
               r_prev_nak <= 0;
               r_prev_contr <= IDLE;
               r_get_decimal_fraction <= 1'b0;
               r_led_reset <= 1;
               r_was_nak <= 0;
               r_data_ready <= 1;
          end
          else begin
          
               r_state <= r_nstate;

               case (r_state)
                    ADDR: begin
                         
                         if(i_addr_ready & (r_i2c_load_data_contr==IDLE)) begin
                              r_i2c_load_data_contr <= LOAD_ADDR;
                         end
                         else if(r_i2c_load_data_contr==LOAD_ADDR & i_data_write_ready) begin
                              r_i2c_load_data_contr <= LOAD_REG;
                         end
                         else if(r_i2c_load_data_contr==LOAD_REG) begin
                              r_i2c_load_data_contr <= CHANGE_VALID;
                         end
                         else if(r_i2c_load_data_contr==CHANGE_VALID & i_nbytes_ready) begin
                              r_i2c_load_data_contr <= LOAD_NBYTES;
                         end
                         else if(r_i2c_load_data_contr==LOAD_NBYTES & i_data_read_valid) begin
                              r_i2c_load_data_contr <= ANALYSE_DATA;
                         end

                         if(!i_nak & (r_i2c_load_data_contr==ANALYSE_DATA) & i_addr_ready) begin  
                              r_nstate <= CONFIGUWRITE;
                              r_counterAck <= 0;
                              r_i2c_load_data_contr <= IDLE;
                         end
                         
                         if(i_nak & !r_prev_nak) begin
                              r_nstate <= ADDR;
                              r_counterAck <= r_counterAck + 1;
                              r_i2c_load_data_contr <= IDLE;
                              r_prev_nak <= i_nak; 
                         end
                         else if(!i_nak) begin
                              r_prev_nak <= i_nak;
                         end

                         if(r_counterAck >= COUNTER_ACK_LIMIT & i_addr_ready) begin
                              r_nstate <= NORESPOND;
                         end

                         case (r_i2c_load_data_contr) 
                              LOAD_ADDR: begin
                                   r_addr_bits <= ADDR_SLAVE_READ;
                                   r_addr_valid <= 1;
                                   r_start <= 1;
                              end
                              LOAD_REG: begin
                                   r_start <= 0;                       //Para generar un pulso del start ya que a este estado ingreso luego de LOAD_ADDR
                                   r_data_write_bits <= SENSOR_DATA; 
                                   r_data_write_valid <= 1;
                              end
                              CHANGE_VALID: begin
                                   r_data_write_valid <= 0;
                                   r_addr_valid <= 0;
                              end
                              LOAD_NBYTES: begin
                                   r_nbytes_bits <= NBYTES;
                                   r_addr_bits <= ADDR_SLAVE_READ;
                                   r_addr_valid <= 1;
                                   r_nbytes_valid <= 1;
                              end
                              ANALYSE_DATA: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_nbytes_bits <= NONE;
                                   r_nbytes_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                              end
                              IDLE: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_nbytes_bits <= NONE;
                                   r_nbytes_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                              end
                         endcase
                         
                    end

                    CONFIGUWRITE: begin

                         if(i_addr_ready & (r_i2c_load_data_contr==IDLE)) begin
                              r_i2c_load_data_contr <= LOAD_ADDR;
                         end
                         else if(r_i2c_load_data_contr==LOAD_ADDR & i_data_write_ready & !r_prev_data_write_ready) begin
                              r_i2c_load_data_contr <= LOAD_REG;
                              r_prev_contr <= LOAD_ADDR;
                         end
                         else if((r_i2c_load_data_contr==LOAD_REG) || (r_i2c_load_data_contr==LOAD_DATA)) begin
                              r_i2c_load_data_contr <= CHANGE_VALID;
                              if(r_prev_contr!=CHANGE_VALID) r_prev_contr <= LOAD_REG;
                         end
                         else if(r_i2c_load_data_contr==CHANGE_VALID & i_data_write_ready  & !r_prev_data_write_ready & r_prev_contr==LOAD_REG) begin
                              r_i2c_load_data_contr <= LOAD_DATA;
                              r_prev_contr <= CHANGE_VALID;
                         end
                         else if(r_i2c_load_data_contr==CHANGE_VALID && r_prev_contr==CHANGE_VALID) begin
                              r_i2c_load_data_contr <= ANALYSE_DATA;
                         end

                         if(!i_nak & (r_i2c_load_data_contr==ANALYSE_DATA) & i_addr_ready) begin  
                              r_nstate <= CONFIGREAD;
                              r_counterAck <= 0;
                              r_i2c_load_data_contr <= IDLE;
                         end
                         
                         if(i_nak & !r_prev_nak) begin
                              r_nstate <= CONFIGUWRITE;
                              r_counterAck <= r_counterAck + 1;
                              r_i2c_load_data_contr <= IDLE;
                              r_prev_nak <= i_nak; 
                         end
                         else if(!i_nak) begin
                              r_prev_nak <= i_nak;
                         end

                         if(r_counterAck >= COUNTER_ACK_LIMIT & i_addr_ready) begin
                              r_nstate <= NORESPOND;
                         end

                         if(r_counterConfig >= COUNTER_CONFIG_LIMIT & i_addr_ready) begin
                              r_nstate <= NORESPOND;
                         end

                         case (r_i2c_load_data_contr)
                              LOAD_ADDR: begin
                                   r_addr_bits <= ADDR_SLAVE_WRITE;
                                   r_addr_valid <= 1;
                                   r_start <= 1;
                              end
                              LOAD_REG: begin
                                   r_start <= 0;                       //Para generar un pulso del start ya que a este estado ingreso luego de LOAD_ADDR
                                   r_data_write_bits <= CONFIG_REGISTER_WRITE; 
                                   r_data_write_valid <= 1;
                              end
                              CHANGE_VALID: begin
                                   r_data_write_valid <= 0;
                                   r_addr_valid <= 0;
                              end
                              LOAD_DATA: begin
                                   r_data_write_bits <= CONFIG_REGISTER_DATA; 
                                   r_data_write_valid <= 1;
                                   r_addr_bits <= ADDR_SLAVE_WRITE;
                                   r_addr_valid <= 1;
                              end
                              ANALYSE_DATA: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                              end
                              IDLE: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                              end

                         endcase
                    end

                    CONFIGREAD: begin

                         if(i_addr_ready & (r_i2c_load_data_contr==IDLE)) begin
                              r_i2c_load_data_contr <= LOAD_ADDR;
                         end
                         else if(r_i2c_load_data_contr==LOAD_ADDR & i_data_write_ready) begin
                              r_i2c_load_data_contr <= LOAD_REG;
                         end
                         else if(r_i2c_load_data_contr==LOAD_REG) begin
                              r_i2c_load_data_contr <= CHANGE_VALID;
                         end
                         else if(r_i2c_load_data_contr==CHANGE_VALID & i_nbytes_ready) begin
                              r_i2c_load_data_contr <= LOAD_NBYTES;
                         end
                         else if(r_i2c_load_data_contr==LOAD_NBYTES & i_data_read_valid) begin
                              r_i2c_load_data_contr <= ANALYSE_DATA;
                         end

                         if(!i_nak & (r_i2c_load_data_contr==ANALYSE_DATA) & i_addr_ready) begin  
                              r_i2c_load_data_contr <= IDLE;
                              if(i_data_read_bits == CONFIG_REGISTER_DATA) begin
                                   r_nstate <= WAIT_REQUEST;
                                   r_counterAck <= 0;
                                   r_counterConfig <= 0;
                              end
                              else begin
                                   r_counterConfig <= r_counterConfig + 1;
                                   r_nstate <= CONFIGUWRITE;
                              end
                         end
                         
                         if(i_nak & !r_prev_nak) begin
                              r_nstate <= CONFIGREAD;
                              r_counterAck <= r_counterAck + 1;
                              r_i2c_load_data_contr <= IDLE;
                              r_prev_nak <= i_nak; 
                         end
                         else if(!i_nak) begin
                              r_prev_nak <= i_nak;
                         end

                         if(r_counterAck >= COUNTER_ACK_LIMIT & i_addr_ready) begin
                              r_nstate <= NORESPOND;
                         end

                         if(r_counterConfig >= COUNTER_CONFIG_LIMIT & i_addr_ready) begin
                              r_nstate <= NORESPOND;
                         end

                         case (r_i2c_load_data_contr)
                              LOAD_ADDR: begin
                                   r_addr_bits <= ADDR_SLAVE_READ;
                                   r_addr_valid <= 1;
                                   r_start <= 1;
                              end
                              LOAD_REG: begin
                                   r_start <= 0;                       //Para generar un pulso del start ya que a este estado ingreso luego de LOAD_ADDR
                                   r_data_write_bits <= CONFIG_REGISTER_READ; 
                                   r_data_write_valid <= 1;
                              end
                              CHANGE_VALID: begin
                                   r_data_write_valid <= 0;
                                   r_addr_valid <= 0;
                              end
                              LOAD_NBYTES: begin
                                   r_nbytes_bits <= NBYTES;
                                   r_addr_bits <= ADDR_SLAVE_READ;
                                   r_addr_valid <= 1;
                                   r_nbytes_valid <= 1;
                              end
                              ANALYSE_DATA: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_nbytes_bits <= NONE;
                                   r_nbytes_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                              end
                              IDLE: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_nbytes_bits <= NONE;
                                   r_nbytes_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                              end
                         endcase
                         
                    end

                    READING: begin

                         if(r_i2c_load_data_contr==IDLE) begin
                              r_i2c_load_data_contr <= WAIT_STATE;
                              if(r_get_decimal_fraction==0) begin
                                   r_nstate <= WAIT_REQUEST;
                              end
                         end
                         else if((i_addr_ready==1) && (r_i2c_load_data_contr==WAIT_STATE)) begin
                              r_i2c_load_data_contr <= LOAD_ADDR;
                         end
                         else if(r_i2c_load_data_contr==LOAD_ADDR & i_data_write_ready) begin
                              r_i2c_load_data_contr <= LOAD_REG;
                         end
                         else if(r_i2c_load_data_contr==LOAD_REG) begin
                              r_i2c_load_data_contr <= CHANGE_VALID;
                         end
                         else if(r_i2c_load_data_contr==CHANGE_VALID & i_nbytes_ready) begin
                              r_i2c_load_data_contr <= LOAD_NBYTES;
                         end
                         else if(r_i2c_load_data_contr==LOAD_NBYTES & i_data_read_valid) begin
                              r_i2c_load_data_contr <= SAVE_DATA;
                              r_counterAck <= 0;                      //La comunicacion volvio a funcionar si antes habia ocurrido un Nack
                         end
                         else if((r_i2c_load_data_contr==SAVE_DATA) & (i_ready_in | i_fifo_full)) begin
                              r_i2c_load_data_contr <= ANALYSE_DATA;
                         end
                         else if(!i_nak & (r_i2c_load_data_contr==ANALYSE_DATA) & i_addr_ready) begin //Revisar i_nak 
                              r_i2c_load_data_contr <= WAIT_SAVE_DATA;
                              r_get_decimal_fraction <= ~r_get_decimal_fraction;
                         end
                         else if(r_i2c_load_data_contr==WAIT_SAVE_DATA) begin
                              r_i2c_load_data_contr <= IDLE;
                         end

                         
                         if(i_nak & !r_prev_nak) begin
                              
                              r_nstate <= READING;
                              r_counterAck <= r_counterAck + 1;
                              if(r_get_decimal_fraction==0) r_i2c_load_data_contr <= WAIT_STATE;
                              else if(r_get_decimal_fraction==1) begin
                                   r_i2c_load_data_contr <= SAVE_DATA;
                                   r_was_nak <= 1;
                              end
                              r_prev_nak <= i_nak; 
                         end
                         else if(!i_nak) begin
                              r_prev_nak <= i_nak;
                         end

                         if((r_counterAck >= COUNTER_ACK_LIMIT) & i_addr_ready) begin
                              r_nstate <= NORESPOND;
                         end

                         case (r_i2c_load_data_contr)
                              LOAD_ADDR: begin
                                   r_addr_bits <= ADDR_SLAVE_READ;
                                   r_addr_valid <= 1;
                                   r_start <= 1;
                                   r_data_ready <= 0;
                              end
                              LOAD_REG: begin
                                   r_start <= 0;                       //Para generar un pulso del start ya que a este estado ingreso luego de LOAD_ADDR
                                   if(!r_get_decimal_fraction) begin
                                        r_data_write_bits <= SENSOR_DATA;
                                   end
                                   else begin
                                        r_data_write_bits <= SENSOR_DECIMAL_FRACTION_DATA;
                                   end
                                   r_data_write_valid <= 1;
                              end
                              CHANGE_VALID: begin
                                   r_data_write_valid <= 0;
                                   r_addr_valid <= 0;
                              end
                              LOAD_NBYTES: begin
                                   r_nbytes_bits <= NBYTES;
                                   r_addr_bits <= ADDR_SLAVE_READ;
                                   r_addr_valid <= 1;
                                   r_nbytes_valid <= 1;
                              end
                              ANALYSE_DATA: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_nbytes_bits <= NONE;
                                   r_nbytes_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                                   if(i_fifo_full) begin
                                        r_data_in_valid <= 0;          //*****
                                   end
                                   else begin
                                        r_data_in_valid <= 1;          //*****
                                   end
                                   
                              end
                              SAVE_DATA: begin
                                   
                                   if(r_was_nak==1) begin
                                        r_data_in <= DATA_HAD_ERROR;
                                   end
                                   else r_data_in <= i_data_read_bits; //*****
                              end
                              WAIT_SAVE_DATA: begin
                                   r_data_in_valid <= 0;
                              end
                              IDLE: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_nbytes_bits <= NONE;
                                   r_nbytes_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                                   r_data_in <= NONE;
                                   r_data_in_valid <= 0;
                                   if(r_get_decimal_fraction==0) r_data_ready <= 1;
                                   else r_data_ready <= 0;
                              end
                              WAIT_STATE: begin
                                   r_addr_bits <= NONE;
                                   r_addr_valid <= 0;
                                   r_nbytes_bits <= NONE;
                                   r_nbytes_valid <= 0;
                                   r_data_write_bits <= NONE; 
                                   r_data_write_valid <= 0;
                                   r_data_in <= NONE;
                                   r_data_in_valid <= 0;
                              end
                         endcase
                    end
                    WAIT_REQUEST: begin

                         r_led_reset <= 1'b0;

                         if(i_request_data==1) begin
                              r_nstate <= READING;
                              r_i2c_load_data_contr <= WAIT_STATE;
                              r_data_ready <= 0;
                         end
                         else r_data_ready <= 1;

                         r_addr_bits <= NONE;
                         r_addr_valid <= 0;
                         r_nbytes_bits <= NONE;
                         r_nbytes_valid <= 0;
                         r_data_write_bits <= NONE; 
                         r_data_write_valid <= 0;
                         r_data_in <= NONE;
                         r_data_in_valid <= 0;
                    end
                    NORESPOND: begin
                         r_nstate <= NORESPOND;
                         r_start <= 0;
                         r_addr_bits <= NONE;
                         r_addr_valid <= 0;
                         r_nbytes_bits <= NONE;
                         r_nbytes_valid <= 0;
                         r_data_read_ready <= 0;
                         r_data_write_bits <= NONE;
                         r_data_write_valid <= 0;
                         r_led_reset <= 0;
                         r_err <= 1;
                    end
                    RESET: begin
                         r_nstate <= ADDR;
                         r_start <= 0;
                         r_addr_bits <= NONE;
                         r_addr_valid <= 0;
                         r_nbytes_bits <= NONE;
                         r_nbytes_valid <= 0;
                         r_data_read_ready <= 0;
                         r_data_write_bits <= NONE;
                         r_data_write_valid <= 0;
                         r_data_in <= NONE;
                         r_data_in_valid <= 0;
                         r_err <= 0;
                    end
                    default: begin
                         r_state <= ADDR;
                         r_start <= 0;
                         r_addr_bits <= NONE;
                         r_addr_valid <= 0;
                         r_nbytes_bits <= NONE;
                         r_nbytes_valid <= 0;
                         r_data_read_ready <= 0;
                         r_data_write_bits <= NONE;
                         r_data_write_valid <= 0;
                         r_data_in <= NONE;
                         r_data_in_valid <= 0;
                         r_err <= 0;
                    end
               endcase

               r_prev_data_write_ready <= i_data_write_ready;

          end
     end

endmodule