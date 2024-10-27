`include "../FSM_I2C_FIFO/FSM_I2C_FIFO.v"
`include "../UART_FSM/UART_FSM.v"
`include "../uart/uart.v"
`include "../uart/uart_rx.v"
`include "../uart/uart_tx.v"
`include "../uart/uart_clkgen.v"

module FSM_I2C_FIFO_UART #(
    parameter DATA_DEPTH = 8, 
    DIV_BITS = 16, 
    DIV_CLK_NUMBER=14,//170,
    NBYTES = 0,                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    ADDR_SLAVE_READ = 157,
    ADDR_SLAVE_WRITE = 156,
    CONFIG_REGISTER_WRITE = 9,         
    CONFIG_REGISTER_READ = 3,          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    CONFIG_REGISTER_DATA = 4,
    SENSOR_DATA = 0,
    SENSOR_DECIMAL_FRACTION_DATA = 21,  //0x15
    ADDR_LENGTH = 8,
    COUNTER_ACK_LIMIT = 25,
    COUNTER_CONFIG_LIMIT = 25,

    //i2c master
    CLK_DIV = 65,                   // 26000000/(65*4) = 100000 Hz
    CLK_DIV_REG_BITS = 24,

    //UART_FSM
    DATA_SENSOR0 = 97,
    DATA_SENSOR1 = 98,
    DATA_SENSOR2 = 99,
    DATA_SENSOR3 = 100,
    DATA_SENSOR4 = 101,
    DATA_SENSOR5 = 102,
    DATA_SENSOR6 = 103,
    DATA_SENSOR7 = 104,
    FSM_SENSOR0 =  105,
    FSM_SENSOR1 =  106,
    FSM_SENSOR2 =  107,
    FSM_SENSOR3 =  108,
    FSM_SENSOR4 =  109,
    FSM_SENSOR5 =  110,
    FSM_SENSOR6 =  111,
    FSM_SENSOR7 =  112,
    FIFO_EMPTY_ERROR_CODE = 85,
    DATA_HAD_ERROR = 7,
    CANT_SENSORES = 8
)(
    input i_clk,
    input i_rst,

    input i_rx,
    output o_tx,

    output [7:0] o_leds,

    inout sda0,            //Para simulacion hay assign comentados en el archivo FSM_I2C_FIFO
    inout scl0,

    inout sda1,            
    inout scl1,

    inout sda2,            
    inout scl2,

    inout sda3,            
    inout scl3,

    inout sda4,            
    inout scl4,

    inout sda5,            
    inout scl5,

    inout sda6,            
    inout scl6,

    inout sda7,            
    inout scl7
);

//--------------------------------------------------------------------------------------------
//FSM I2C y FIFO
//--------------------------------------------------------------------------------------------

/*

                                         __________
                                        |          |
           i_fifo_data_out_extracted--->|          |
                                        |          |
                                        |   I2C    |
                                        |   FSM    |<--->sda
                     o_fifo_data_out<---|   FIFO   |<--->scl
                                        |          |
                                        |          |
    o_fifo_data_out_valid_to_extract<---|          |
                                        |__________|             
            
*/

//-------------------
//wires and registers
//-------------------

wire [CANT_SENSORES-1:0] w_request_data;
wire [CANT_SENSORES-1:0] w_data_ready;

wire aux;

wire w_fsm0_rst;
wire w_fifo0_empty;
wire w_fifo0_data_out_extracted;
wire w_fifo0_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo0_data_out;

wire w_fsm1_rst;
wire w_fifo1_empty;
wire w_fifo1_data_out_extracted;
wire w_fifo1_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo1_data_out;

wire w_fsm2_rst;
wire w_fifo2_empty;
wire w_fifo2_data_out_extracted;
wire w_fifo2_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo2_data_out;

wire w_fsm3_rst;
wire w_fifo3_empty;
wire w_fifo3_data_out_extracted;
wire w_fifo3_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo3_data_out;

wire w_fsm4_rst;
wire w_fifo4_empty;
wire w_fifo4_data_out_extracted;
wire w_fifo4_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo4_data_out;

wire w_fsm5_rst;
wire w_fifo5_empty;
wire w_fifo5_data_out_extracted;
wire w_fifo5_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo5_data_out;

wire w_fsm6_rst;
wire w_fifo6_empty;
wire w_fifo6_data_out_extracted;
wire w_fifo6_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo6_data_out;

wire w_fsm7_rst;
wire w_fifo7_empty;
wire w_fifo7_data_out_extracted;
wire w_fifo7_data_out_valid_to_extract;
wire [DATA_DEPTH-1:0] w_fifo7_data_out;

//Input Output interface
wire w_sda_oe;
wire w_sda_o;
wire w_sda_i;

//Input output interface
wire w_scl_oe;
wire w_scl_o;
wire w_scl_i;

//--------------------------------------------------------------------------------------------
//UART_FSM
//--------------------------------------------------------------------------------------------

/*

                                         __________
                                        |          |
                 i_uart_recived_data--->|          |
                i_uart_recived_valid--->|          |
           o_uart_recived_data_ready<---|          |
                                        |   UART   |--->o_fifo0_data_out_extracted
                    o_uart_send_data<---|   FSM    |<---i_fifo0_data_out_valid_to_extract
                   o_uart_send_valid<---|          |<---i_fifo0_data_out
              i_uart_send_data_ready--->|          |
                                        |          |
                                        |__________|             
            
*/

//-------------------
//wires and registers
//-------------------

wire [DATA_DEPTH-1:0] w_uart_fsm_recived_data;
wire w_uart_recived_valid;
wire w_uart_recived_data_ready;

wire [DATA_DEPTH-1:0] w_uart_send_data;
wire w_uart_send_valid;
wire w_uart_send_data_ready;

wire [DATA_DEPTH-1:0] w_uart_recived_data;

//--------------------------------------------------------------------------------------------
//UART
//--------------------------------------------------------------------------------------------

/*

              __________
             |          |
    i_rxd--->|          |--->o_data
    o_txd<---|          |--->o_valid
             |          |<---i_ready
             |          |
             |   UART   |<---i_data
             |          |<---i_valid
             |          |--->o_ready
  o_rxerr<---|          |
             |__________|             
            
*/

//-------------------
//wires and registers
//-------------------

reg [DIV_BITS-1:0] r_div = DIV_CLK_NUMBER;

wire w_rxerr;

//--------------------------------------------------------------------------------------------
//UART and FIFO LOGIC
//--------------------------------------------------------------------------------------------

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT),
    .DATA_HAD_ERROR(DATA_HAD_ERROR)
) FSM_I2C_FIFO_0 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm0_rst),

    .i_request_data(w_request_data[0]),
    .o_data_ready(w_data_ready[0]), 

    .sda(sda0),
    .scl(scl0),

    .o_led_fsm_err(o_leds[0]),

    .i_fifo_data_out_extracted(w_fifo0_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo0_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo0_data_out),

    .o_fifo_empty(w_fifo0_empty)

);

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT)
) FSM_I2C_FIFO_1 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm1_rst),

    .i_request_data(w_request_data[1]),
    .o_data_ready(w_data_ready[1]), 

    .sda(sda1),
    .scl(scl1),

    .o_led_fsm_err(o_leds[1]),

    .i_fifo_data_out_extracted(w_fifo1_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo1_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo1_data_out),

    .o_fifo_empty(w_fifo1_empty)

);

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT)
) FSM_I2C_FIFO_2 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm2_rst),

    .i_request_data(w_request_data[2]),
    .o_data_ready(w_data_ready[2]), 

    .sda(sda2),
    .scl(scl2),

    .o_led_fsm_err(o_leds[2]),

    .i_fifo_data_out_extracted(w_fifo2_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo2_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo2_data_out),

    .o_fifo_empty(w_fifo2_empty)

);

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT)
) FSM_I2C_FIFO_3 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm3_rst),

    .i_request_data(w_request_data[3]),
    .o_data_ready(w_data_ready[3]), 

    .sda(sda3),
    .scl(scl3),

    .o_led_fsm_err(o_leds[3]),

    .i_fifo_data_out_extracted(w_fifo3_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo3_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo3_data_out),

    .o_fifo_empty(w_fifo3_empty)

);

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT)
) FSM_I2C_FIFO_4 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm4_rst),

    .i_request_data(w_request_data[4]),
    .o_data_ready(w_data_ready[4]), 

    .sda(sda4),
    .scl(scl4),

    .o_led_fsm_err(o_leds[4]),

    .i_fifo_data_out_extracted(w_fifo4_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo4_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo4_data_out),

    .o_fifo_empty(w_fifo4_empty)

);

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT)
) FSM_I2C_FIFO_5 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm5_rst),

    .i_request_data(w_request_data[5]),
    .o_data_ready(w_data_ready[5]), 

    .sda(sda5),
    .scl(scl5),

    .o_led_fsm_err(o_leds[5]),

    .i_fifo_data_out_extracted(w_fifo5_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo5_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo5_data_out),

    .o_fifo_empty(w_fifo5_empty)

);

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT)
) FSM_I2C_FIFO_6 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm6_rst),

    .i_request_data(w_request_data[6]),
    .o_data_ready(w_data_ready[6]), 

    .sda(sda6),
    .scl(scl6),

    .o_led_fsm_err(o_leds[6]),

    .i_fifo_data_out_extracted(w_fifo6_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo6_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo6_data_out),

    .o_fifo_empty(w_fifo6_empty)

);

FSM_I2C_FIFO #(
    .DATA_DEPTH(DATA_DEPTH),  
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .ADDR_LENGTH(ADDR_LENGTH),
    //i2c master
    .CLK_DIV(CLK_DIV),
    .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT)
) FSM_I2C_FIFO_7 (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_fsm_rst(w_fsm7_rst),

    .i_request_data(w_request_data[7]),
    .o_data_ready(w_data_ready[7]), 

    .sda(sda7),
    .scl(scl7),

    .o_led_fsm_err(o_leds[7]),

    .i_fifo_data_out_extracted(w_fifo7_data_out_extracted),
    .o_fifo_data_out_valid_to_extract(w_fifo7_data_out_valid_to_extract),
    .o_fifo_data_out(w_fifo7_data_out),

    .o_fifo_empty(w_fifo7_empty)

);

//--------------------------------------------------------------------------------------------
//UART_FSM
//--------------------------------------------------------------------------------------------

/*

                                         __________
                                        |          |
                 i_uart_recived_data--->|          |
                i_uart_recived_valid--->|          |
           o_uart_recived_data_ready<---|          |
                                        |   UART   |--->o_fifo0_data_out_extracted
                    o_uart_send_data<---|   FSM    |<---i_fifo0_data_out_valid_to_extract
                   o_uart_send_valid<---|          |<---i_fifo0_data_out
              i_uart_send_data_ready--->|          |
                                        |          |
                                        |__________|             
            
*/

UART_FSM #(.DATA_DEPTH(DATA_DEPTH),
    .DATA_SENSOR0(DATA_SENSOR0),
    .DATA_SENSOR1(DATA_SENSOR1),
    .DATA_SENSOR2(DATA_SENSOR2),
    .DATA_SENSOR3(DATA_SENSOR3),
    .DATA_SENSOR4(DATA_SENSOR4),
    .DATA_SENSOR5(DATA_SENSOR5),
    .DATA_SENSOR6(DATA_SENSOR6),
    .DATA_SENSOR7(DATA_SENSOR7),
    .FSM_SENSOR0(FSM_SENSOR0),
    .FSM_SENSOR1(FSM_SENSOR1),
    .FSM_SENSOR2(FSM_SENSOR2),
    .FSM_SENSOR3(FSM_SENSOR3),
    .FSM_SENSOR4(FSM_SENSOR4),
    .FSM_SENSOR5(FSM_SENSOR5),
    .FSM_SENSOR6(FSM_SENSOR6),
    .FSM_SENSOR7(FSM_SENSOR7),
    .FIFO_EMPTY_ERROR_CODE(FIFO_EMPTY_ERROR_CODE),
    .CANT_SENSORES(CANT_SENSORES)
)
UART_FSM (
    .i_clk(i_clk),
    .i_rst(i_rst),

    .o_request_data(w_request_data),
    .i_data_ready(w_data_ready),

    .i_uart_recived_data(w_uart_fsm_recived_data),
    .i_uart_recived_valid(w_uart_recived_valid),
    .o_uart_recived_data_ready(w_uart_recived_data_ready),

    .o_uart_send_data(w_uart_send_data),
    .o_uart_send_valid(w_uart_send_valid),
    .i_uart_send_data_ready(w_uart_send_data_ready),

    .o_fifo0_data_out_extracted(w_fifo0_data_out_extracted),
    .i_fifo0_data_out_valid_to_extract(w_fifo0_data_out_valid_to_extract),
    .i_fifo0_data_out(w_fifo0_data_out),
    .o_fsm0_rst(w_fsm0_rst),
    .i_fifo0_empty(w_fifo0_empty),

    .o_fifo1_data_out_extracted(w_fifo1_data_out_extracted),
    .i_fifo1_data_out_valid_to_extract(w_fifo1_data_out_valid_to_extract),
    .i_fifo1_data_out(w_fifo1_data_out),
    .o_fsm1_rst(w_fsm1_rst),
    .i_fifo1_empty(w_fifo1_empty),

    .o_fifo2_data_out_extracted(w_fifo2_data_out_extracted),
    .i_fifo2_data_out_valid_to_extract(w_fifo2_data_out_valid_to_extract),
    .i_fifo2_data_out(w_fifo2_data_out),
    .o_fsm2_rst(w_fsm2_rst),
    .i_fifo2_empty(w_fifo2_empty),

    .o_fifo3_data_out_extracted(w_fifo3_data_out_extracted),
    .i_fifo3_data_out_valid_to_extract(w_fifo3_data_out_valid_to_extract),
    .i_fifo3_data_out(w_fifo3_data_out),
    .o_fsm3_rst(w_fsm3_rst),
    .i_fifo3_empty(w_fifo3_empty),

    .o_fifo4_data_out_extracted(w_fifo4_data_out_extracted),
    .i_fifo4_data_out_valid_to_extract(w_fifo4_data_out_valid_to_extract),
    .i_fifo4_data_out(w_fifo4_data_out),
    .o_fsm4_rst(w_fsm4_rst),
    .i_fifo4_empty(w_fifo4_empty),

    .o_fifo5_data_out_extracted(w_fifo5_data_out_extracted),
    .i_fifo5_data_out_valid_to_extract(w_fifo5_data_out_valid_to_extract),
    .i_fifo5_data_out(w_fifo5_data_out),
    .o_fsm5_rst(w_fsm5_rst),
    .i_fifo5_empty(w_fifo5_empty),

    .o_fifo6_data_out_extracted(w_fifo6_data_out_extracted),
    .i_fifo6_data_out_valid_to_extract(w_fifo6_data_out_valid_to_extract),
    .i_fifo6_data_out(w_fifo6_data_out),
    .o_fsm6_rst(w_fsm6_rst),
    .i_fifo6_empty(w_fifo6_empty),

    .o_fifo7_data_out_extracted(w_fifo7_data_out_extracted),
    .i_fifo7_data_out_valid_to_extract(w_fifo7_data_out_valid_to_extract),
    .i_fifo7_data_out(w_fifo7_data_out),
    .o_fsm7_rst(w_fsm7_rst),
    .i_fifo7_empty(w_fifo7_empty)
);

//--------------------------------------------------------------------------------------------
//UART
//--------------------------------------------------------------------------------------------

/*

              __________
             |          |
    i_rxd--->|          |--->o_data
    o_txd<---|          |--->o_valid
             |          |<---i_ready
             |          |
             |   UART   |<---i_data
             |          |<---i_valid
             |          |--->o_ready
  o_rxerr<---|          |
             |__________|             
            
*/

uart #(.DIV_BITS(DIV_BITS)) uart(
    .i_clk(i_clk),
    .i_rst(i_rst),

    .i_div(r_div),

    .i_rxd(i_rx),
    .o_txd(o_tx),

    .o_data(w_uart_recived_data),            //Datos recividos
    .o_valid(w_uart_recived_valid),          //Datos recividos extraidos
    .i_ready(w_uart_recived_data_ready),     //Infromacion lista para ser extraida de nuevo

    .i_data(w_uart_send_data),               //Datos a enviar
    .i_valid(w_uart_send_valid),             //Datos a enviar tomados o no tomados
    .o_ready(w_uart_send_data_ready),        //Informacion enviada o lista para enviar

    .o_rxerr()

);

assign w_uart_fsm_recived_data = w_uart_recived_data;

endmodule

