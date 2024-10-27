`include "../FSM/FSM.v"
`include "../i2c_master/i2c_master_oe.v"
`include "../fifo/fifo_internal/fifo_internal.v"
`include "../fifo/interface/fifo.v"
`include "../fifo/ram_dualport.v"

module FSM_I2C_FIFO #(
    parameter DATA_DEPTH = 8,  
    NBYTES = 0,                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    ADDR_SLAVE_READ = 79,
    ADDR_SLAVE_WRITE = 78,
    CONFIG_REGISTER_WRITE = 3,         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    CONFIG_REGISTER_READ = 3,          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    CONFIG_REGISTER_DATA = 4,
    SENSOR_DATA = 0,
    SENSOR_DECIMAL_FRACTION_DATA = 15,
    ADDR_LENGTH = 8,
    //i2c master
    CLK_DIV = 16,
    CLK_DIV_REG_BITS = 24,
    COUNTER_ACK_LIMIT = 25,
    COUNTER_CONFIG_LIMIT = 25,
    DATA_HAD_ERROR = 7
) (
    input i_clk,
    input i_rst,
    input i_fsm_rst,

    input i_request_data,
    output reg o_data_ready, 

    inout sda,
    inout scl,

    output reg o_led_fsm_err,

    input i_fifo_data_out_extracted,
    output o_fifo_data_out_valid_to_extract,
    output [DATA_DEPTH-1:0] o_fifo_data_out,

    output o_fifo_empty

);

//--------------------------------------------------------------------------------------------
//FSM and I2C master
//--------------------------------------------------------------------------------------------

//-------------------
//Wires and registers
//-------------------

wire w_start;
wire w_nak;
wire w_request_data;
wire w_data_ready;

wire w_addr_ready;
wire [DATA_DEPTH-1:0] w_addr_bits;
wire w_addr_valid;

//read parameters
wire w_nbytes_ready;
wire [DATA_DEPTH-1:0] w_nbytes_bits;
wire w_nbytes_valid;

//read interface
wire [DATA_DEPTH-1:0] w_data_read_bits;
wire w_data_read_valid;
wire w_data_read_ready;

//write interface
wire w_data_write_ready;         
wire [DATA_DEPTH-1:0] w_data_write_bits;
wire w_data_write_valid;

//FSM fifo interface
wire w_fifo_full;
wire w_fifo_empty;

//-------------------
//Modules
//-------------------

FSM #(
    .DATA_DEPTH(DATA_DEPTH),
    .NBYTES(NBYTES),                        //El i2c_master empieza a contar desde el cero (0=leer una vez)
    .ADDR_SLAVE_READ(ADDR_SLAVE_READ),
    .ADDR_SLAVE_WRITE(ADDR_SLAVE_WRITE),
    .CONFIG_REGISTER_WRITE(CONFIG_REGISTER_WRITE),         //A modo de prueba se cambio el valor para que sea el mismo y se pueda comprobar
    .CONFIG_REGISTER_READ(CONFIG_REGISTER_READ),          //el valor real del sensor de temperatura es 0x09 para escribir y 0x03 para leer
    .CONFIG_REGISTER_DATA(CONFIG_REGISTER_DATA),
    .SENSOR_DATA(SENSOR_DATA),
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA),
    .COUNTER_ACK_LIMIT(COUNTER_ACK_LIMIT),
    .COUNTER_CONFIG_LIMIT(COUNTER_CONFIG_LIMIT),
    .DATA_HAD_ERROR(DATA_HAD_ERROR)
    ) 
    FSM(
    .i_clk(i_clk), 
    .i_rst(i_rst),

    .i_force_rst(i_fsm_rst),

    //control
    .o_start(w_start),
    .i_request_data(i_request_data),
    .o_data_ready(o_data_ready),  
    
    //addr interface
    .i_addr_ready(w_addr_ready),
    .o_addr_bits(w_addr_bits), 
    .o_addr_valid(w_addr_valid),

    //read parameters
    .i_nbytes_ready(w_nbytes_ready),
    .o_nbytes_bits(w_nbytes_bits),
    .o_nbytes_valid(w_nbytes_valid),

    //read interface
    .i_data_read_bits(w_data_read_bits),
    .i_data_read_valid(w_data_read_valid),
    .o_data_read_ready(w_data_read_ready),

    //write interface
    .i_data_write_ready(w_data_write_ready),                         
    .o_data_write_bits(w_data_write_bits),
    .o_data_write_valid(w_data_write_valid),

    .i_nak(w_nak),

    .i_ready_in(w_ready_in),
    .o_data_in(w_data_in),
    .o_data_in_valid(w_data_in_valid),

    .i_fifo_full(w_fifo_full),
    .o_err(o_led_fsm_err)

);

i2c_master_oe #(.DATA_DEPTH(DATA_DEPTH), .CLK_DIV(CLK_DIV), .CLK_DIV_REG_BITS(CLK_DIV_REG_BITS)) 
i2c_master(
    //control
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_start(w_start), 

    //stream input addr interface
    .i_addr_bits(w_addr_bits),
    .i_addr_valid(w_addr_valid),
    .o_addr_ready(w_addr_ready),

    //stream input number of bytes to read
    .i_nbytes_bits(w_nbytes_bits),
    .i_nbytes_valid(w_nbytes_valid),
    .o_nbytes_ready(w_nbytes_ready),

    //stream input data interface
    .i_data_bits(w_data_write_bits),
    .i_data_valid(w_data_write_valid),
    .o_data_ready(w_data_write_ready),

    //stream output read data
    .o_data_bits(w_data_read_bits),
    .o_data_valid(w_data_read_valid),
    .i_data_ready(w_data_read_ready),

    //i2c lines splitted for manual instantiation
    //of io ports

    //strict input lines
    .i_sda_in(w_sda_i),
    .i_scl_in(w_scl_i),
    
    //tristate buffers separate lines
    .o_sda_oe(w_sda_oe),
    .o_scl_oe(w_scl_oe),

    //strict output lines
    .o_sda_out(w_sda_o),
    .o_scl_out(w_scl_o),
    
    .o_nak(w_nak)
);

//--------------------------------------------------------------------------------------------
//FIFO
//--------------------------------------------------------------------------------------------

/*
                      __________
                     |          |
        ready_out--->|          |<---data_in
         data_out<---|   FIFO   |<---data_in_valid
   data_out_valid<---|          |--->ready_in
                     |__________|

*/

//-------------------
//wires and registers
//-------------------

//Escritura
wire w_ready_in;
wire [DATA_DEPTH-1:0] w_data_in;
wire w_data_in_valid;
//Lectura

FIFO #(.ADDR_LENGTH(DATA_DEPTH), .WORD_LENGTH(DATA_DEPTH))
fifo(
    .i_clk(i_clk), 
    .i_reset(i_rst),

    .i_data_in(w_data_in),
    .i_data_in_valid(w_data_in_valid),
    .o_ready_in(w_ready_in),

    .o_data_out(o_fifo_data_out),
    .o_data_out_valid(o_fifo_data_out_valid_to_extract),
    .i_ready_out(i_fifo_data_out_extracted),

    .o_full(w_fifo_full),
    .o_empty(o_fifo_empty)
);

//--------------------------------------------------------------------------------------------
//SB_IO Instantiation
//--------------------------------------------------------------------------------------------

wire w_sda_oe;
wire w_sda_o;
wire w_sda_i;

wire w_scl_oe;
wire w_scl_o;
wire w_scl_i;

wire w_clock_enable;
wire w_d_out_0;
wire w_d_in_0;
wire w_d_out_1;
wire w_d_in_1;
reg r_latch_input_value = 1'b0;

wire w_package_pin_scl;
wire w_package_pin_sda;


assign w_package_pin_scl = scl;
assign w_package_pin_sda = sda;

/*

//Metodo para simular

assign sda = w_sda_oe ? w_sda_o : 1'bz;
assign w_sda_i = sda;
assign scl = w_scl_o;
assign w_scl_i = scl;

*/

//-------
//SDA pin
//-------

SB_IO
IO_PIN_SDA_INST
(
.PACKAGE_PIN (w_package_pin_sda),                 // User’s Pin signal name
.LATCH_INPUT_VALUE (r_latch_input_value),     // Latches/holds the Input value
.CLOCK_ENABLE (w_clock_enable),             // Clock Enable common to input and output clock
.INPUT_CLK (i_clk),                         // Clock for the input registers
.OUTPUT_CLK (i_clk),                        // Clock for the output registers
.OUTPUT_ENABLE (w_sda_oe),                  // Output Pin Tristate/Enable control
.D_OUT_0 (w_sda_o),                         // Data 0 – out to Pin/Rising clk edge
.D_OUT_1 (w_d_out_0),                         // Data 1 - out to Pin/Falling clk edge
.D_IN_0 (w_sda_i),                           // Data 0 - Pin input/Rising clk edge
.D_IN_1 (w_d_in_0)                            // Data 1 – Pin input/Falling clk edge
); // synthesis DRIVE_STRENGTH= x2

defparam IO_PIN_SDA_INST.PIN_TYPE = 6'b101001;
// See Input and Output Pin Function Tables.
// Default value of PIN_TYPE = 6’000000 i.e.
// an input pad, with the input signal
// registered.
defparam IO_PIN_SDA_INST.PULLUP = 1'b1;             //<---------------------1'b0
// By default, the IO will have NO pull up.
// This parameter is used only on bank 0, 1,
// and 2. Ignored when it is placed at bank 3
defparam IO_PIN_SDA_INST.NEG_TRIGGER = 1'b0;
// Specify the polarity of all FFs in the IO to
// be falling edge when NEG_TRIGGER = 1.
// Default is rising edge.
defparam IO_PIN_SDA_INST.IO_STANDARD = "SB_LVCMOS";
// Other IO standards are supported in bank 3
// only: SB_SSTL2_CLASS_2, SB_SSTL2_CLASS_1,
// SB_SSTL18_FULL, SB_SSTL18_HALF, SB_MDDR10,
// SB_MDDR8, SB_MDDR4, SB_MDDR2 etc.

//-------
//SCL pin
//-------

SB_IO
IO_PIN_SCL_INST
(
.PACKAGE_PIN (w_package_pin_scl),                 // User’s Pin signal name
.LATCH_INPUT_VALUE (r_latch_input_value),     // Latches/holds the Input value
.CLOCK_ENABLE (w_clock_enable),             // Clock Enable common to input and output clock
.INPUT_CLK (i_clk),                         // Clock for the input registers
.OUTPUT_CLK (i_clk),                        // Clock for the output registers
.OUTPUT_ENABLE (w_scl_oe),                  // Output Pin Tristate/Enable control
.D_OUT_0 (w_scl_o),                         // Data 0 – out to Pin/Rising clk edge
.D_OUT_1 (w_d_out_1),                         // Data 1 - out to Pin/Falling clk edge
.D_IN_0 (w_scl_i),                           // Data 0 - Pin input/Rising clk edge
.D_IN_1 (w_d_in_1)                            // Data 1 – Pin input/Falling clk edge
); //synthesis DRIVE_STRENGTH= x2
defparam IO_PIN_SCL_INST.PIN_TYPE = 6'b101001;
// See Input and Output Pin Function Tables.
// Default value of PIN_TYPE = 6’000000 i.e.
// an input pad, with the input signal
// registered.
defparam IO_PIN_SCL_INST.PULLUP = 1'b1;             //<---------------------1'b0
// By default, the IO will have NO pull up.
// This parameter is used only on bank 0, 1,
// and 2. Ignored when it is placed at bank 3
defparam IO_PIN_SCL_INST.NEG_TRIGGER = 1'b0;
// Specify the polarity of all FFs in the IO to
// be falling edge when NEG_TRIGGER = 1.
// Default is rising edge.
defparam IO_PIN_SCL_INST.IO_STANDARD = "SB_LVCMOS";
// Other IO standards are supported in bank 3
// only: SB_SSTL2_CLASS_2, SB_SSTL2_CLASS_1,
// SB_SSTL18_FULL, SB_SSTL18_HALF, SB_MDDR10,
// SB_MDDR8, SB_MDDR4, SB_MDDR2 etc.

//--------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------

endmodule