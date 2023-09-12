`timescale 1us / 1ns

module spi_slave #(
    parameter CLK_RATE = 100000,
    parameter DATA_LEN = 8
) (
    input                   clk,
    input                   rst,
    // axi stream to transmit
    input [DATA_LEN-1:0]    tx_tdata,
    input                   tx_tvalid,
    output                  tx_tready,
    // axi stream to receive
    output [DATA_LEN-1:0]   rx_tdata,
    output                  rx_tvalid,
    input                   rx_tready,
    // spi
    output                  spi_miso,
    input                   spi_mosi,
    input                   spi_sclk,
    input                   spi_cs_n
);

    // axi registers
    reg [DATA_LEN-1:0] tx_tdata_d, tx_tdata_q;
    reg tx_tvalid_d, tx_tvalid_q;
    reg tx_tready_d, tx_tready_q;

    reg [DATA_LEN-1:0] rx_tdata_d, rx_tdata_q;
    reg rx_tvalid_d, rx_tvalid_q;
    reg rx_tready_d, rx_tready_q;

    // assign tx_tdata_d = tx_tdata;  // conviene registrarlo?
    assign tx_tvalid_d = tx_tvalid;
    assign tx_tready = tx_tready_q;

    assign rx_tdata = rx_tdata_q;
    assign rx_tvalid = rx_tvalid_q;
    assign rx_tready_d = rx_tready;

    always @(posedge clk) begin
        if (rst) begin
            tx_tdata_q <= '0;
            tx_tvalid_q <= 0;
            tx_tready_q <= 1;

            rx_tdata_q <= '0;
            rx_tvalid_q <= 0;
            rx_tready_q <= 0;

            current_state_axi_tx <= TX_IDLE;
            current_state_axi_rx <= RX_IDLE;
        end
        else begin
            tx_tdata_q <= tx_tdata_d;
            tx_tvalid_q <= tx_tvalid_d;
            tx_tready_q <= tx_tready_d;

            rx_tdata_q <= rx_tdata_d;
            rx_tvalid_q <= rx_tvalid_d;
            rx_tready_q <= rx_tready_d;

            current_state_axi_tx <= next_state_axi_tx;
            current_state_axi_rx <= next_state_axi_rx;
        end
    end

    // axi fsm
    typedef enum {TX_IDLE, TX_PENDING, TX_WAITING, TX_TRANSMITTING} fsm_state_axi_tx_e;
    fsm_state_axi_tx_e current_state_axi_tx = TX_IDLE;
    fsm_state_axi_tx_e next_state_axi_tx    = TX_IDLE;

    typedef enum {RX_IDLE, RX_RECEIVING, RX_READY} fsm_state_axi_rx_e;
    fsm_state_axi_rx_e current_state_axi_rx = RX_IDLE;
    fsm_state_axi_rx_e next_state_axi_rx    = RX_IDLE;
    
    always @(*) begin
        next_state_spi = current_state_spi;

        spi_tx_data_d = spi_tx_data_q;
        spi_rx_data_d = spi_rx_data_q;
        spi_counter_d = spi_counter_q;

        case (current_state_spi)
            SPI_IDLE: begin
                if (~spi_cs_n_q) begin
                    next_state_spi = SPI_RUNNING;
                end
            end
            SPI_RUNNING: begin
                if (spi_sclk_d & ~spi_sclk_q & spi_counter_q != '0) begin
                    // rising edge
                    spi_tx_data_d = {spi_tx_data_q[DATA_LEN-2:0], '0};
                end
                else if (~spi_sclk_d & spi_sclk_q) begin
                    // falling edge
                    spi_rx_data_d = {spi_rx_data_q[DATA_LEN-2:0], spi_mosi_q};
                    spi_counter_d = spi_counter_q + 'd1;
                end
                else if (spi_counter_q == DATA_LEN) begin
                    next_state_spi = SPI_IDLE;
                    spi_counter_d = '0;
                end
            end
            default: begin
                next_state_spi = SPI_IDLE;
                spi_tx_data_d = '0;
                spi_rx_data_d = '0;
                spi_counter_d = '0;
            end
        endcase

        next_state_axi_tx = current_state_axi_tx;
        tx_tdata_d = tx_tdata_q;
        tx_tready_d = tx_tready_q;

        case (current_state_axi_tx)
            TX_IDLE: begin
                if (tx_tvalid_q == 1) begin
                    next_state_axi_tx = TX_PENDING;
                    tx_tready_d = 0;
                    tx_tdata_d = tx_tdata;
                end
            end
            TX_PENDING: begin
                if (current_state_spi == SPI_IDLE) begin
                    next_state_axi_tx = TX_WAITING;
                    spi_tx_data_d = tx_tdata_q;
                end
            end
            TX_WAITING: begin
                if (current_state_spi == SPI_RUNNING) begin
                    next_state_axi_tx = TX_TRANSMITTING;
                end
            end
            TX_TRANSMITTING: begin
                if (current_state_spi == SPI_IDLE) begin
                    next_state_axi_tx = TX_IDLE;
                    tx_tready_d = 1;
                end
            end
            default: begin
                next_state_axi_tx = TX_IDLE;
                tx_tready_d = 1;
                tx_tdata_d = '0;
                spi_tx_data_d = '0;
            end
        endcase

        next_state_axi_rx = current_state_axi_rx;
        rx_tdata_d = rx_tdata_q;
        rx_tvalid_d = rx_tvalid_q;

        case (current_state_axi_rx)
            RX_IDLE: begin
                if (current_state_spi == SPI_RUNNING) begin
                    next_state_axi_rx = RX_RECEIVING;
                end
            end
            RX_RECEIVING: begin
                if (current_state_spi == SPI_IDLE) begin
                    next_state_axi_rx = RX_READY;
                    rx_tdata_d = spi_rx_data_q;
                    rx_tvalid_d = 1;
                end
            end
            RX_READY: begin
                if (rx_tready_q == 1) begin
                    next_state_axi_rx = RX_IDLE;
                    rx_tvalid_d = 0;
                end
            end
            default: begin
                next_state_axi_rx = RX_IDLE;
                rx_tdata_d = '0;
                rx_tvalid_d = 0;
            end
        endcase
    end

    // spi registers
    localparam DATA_COUNTER_LEN = $clog2(DATA_LEN);
    reg [DATA_COUNTER_LEN:0] spi_counter_d, spi_counter_q;
    
    reg [DATA_LEN-1:0] spi_tx_data_d, spi_tx_data_q;
    reg [DATA_LEN-1:0] spi_rx_data_d, spi_rx_data_q;

    reg spi_sclk_d, spi_sclk_q;
    reg spi_mosi_d, spi_mosi_q;
    reg spi_cs_n_d, spi_cs_n_q;

    assign spi_sclk_d = spi_sclk;
    assign spi_miso = spi_tx_data_q[DATA_LEN-1];
    assign spi_mosi_d = spi_mosi;
    assign spi_cs_n_d = spi_cs_n;

    always @(posedge clk) begin
        if (rst) begin
            spi_counter_q <= '0;
            spi_tx_data_q <= '0;
            spi_rx_data_q <= '0;

            spi_sclk_q <= 0;
            spi_mosi_q <= 0;
            spi_cs_n_q <= 1;

            current_state_spi <= SPI_IDLE;
        end
        else begin
            spi_counter_q <= spi_counter_d;
            spi_tx_data_q <= spi_tx_data_d;
            spi_rx_data_q <= spi_rx_data_d;

            spi_sclk_q <= spi_sclk_d;
            spi_mosi_q <= spi_mosi_d;
            spi_cs_n_q <= spi_cs_n_d;

            current_state_spi <= next_state_spi;
        end
    end

    // spi fsm
    typedef enum {SPI_IDLE, SPI_RUNNING} fsm_state_spi_e;
    fsm_state_spi_e current_state_spi = SPI_IDLE;
    fsm_state_spi_e next_state_spi    = SPI_IDLE;

endmodule
