`include "../FSM/FSM.v"
`include "../i2c_master/i2c_master_oe.v"
`include "../fifo/fifo_internal/fifo_internal.v"
`include "../fifo/interface/fifo.v"
`include "../fifo/ram_dualport.v"

module fsm_i2c_fifo #(
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
    CLK_DIV_REG_BITS = 24
) (
    input i_clk,
    input i_rst,
    input i_fsm_rst,

    //strict input lines
    input i_sda_in,
    input i_scl_in,
    
    //tristate buffers separate lines
    output reg o_sda_oe,
    output reg o_scl_oe,

    //strict output lines
    output reg o_sda_out,
    output reg o_scl_out,

    input i_fifo_data_out_extracted,
    output reg o_fifo_data_out_valid_to_extract,
    output reg [DATA_DEPTH-1:0] o_fifo_data_out

);
    
//--------------------------------------------------------------------------------------------
//FSM and I2C master
//--------------------------------------------------------------------------------------------

//-------------------
//Wires and registers
//-------------------

wire w_start;
wire w_nak;

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
wire w_led_fsm_err;

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
    .SENSOR_DECIMAL_FRACTION_DATA(SENSOR_DECIMAL_FRACTION_DATA)
    ) 
    FSM(
    .i_clk(i_clk), 
    .i_rst(i_rst),

    .i_force_rst(i_fsm_rst),

    //control
    .o_start(w_start), 
    
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
    .o_err(w_led_fsm_err)
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
    .i_sda_in(i_sda_in),
    .i_scl_in(i_scl_in),
    
    //tristate buffers separate lines
    .o_sda_oe(o_sda_oe),
    .o_scl_oe(o_scl_oe),

    //strict output lines
    .o_sda_out(o_sda_out),
    .o_scl_out(o_scl_out),
    
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
    .o_empty(w_fifo_empty)
);

always @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
    
    end
    else begin
        r_fsm_addr_bits <= r_i2c_master_addr_bits;
    end
end

endmodule