module uart_command_top #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE = 115_200
) (
    input logic clk,
    input logic rst_n,

    input logic uart_rx_pin,
    output logic uart_tx_pin
);

logic running;
logic clear_pulse;

logic [7:0] rx_data;
logic rx_valid;

logic [7:0] time_data;
logic time_valid;
logic time_ready;

logic cmd_time;
logic cmd_start;
logic cmd_stop;
logic cmd_clear;

logic cmd_unknown;

logic [4:0] hours;
logic [5:0] minutes;
logic [5:0] seconds;
logic [6:0] centis;

command_executor u_command_executor (
    .clk(clk),
    .rst_n(rst_n),

    .cmd_start(cmd_start),
    .cmd_stop(cmd_stop),
    .cmd_clear(cmd_clear),

    .running(running),
    .clear_pulse(clear_pulse)
);

time_response_gen u_time_response_gen (
    .clk(clk),
    .rst_n(rst_n),
    .cmd_time(cmd_time),

    .hours(hours),
    .minutes(minutes),
    .seconds(seconds),
    .centis(centis),

    .m_ready(time_ready),
    
    .m_data(time_data),
    .m_valid(time_valid)
);

uart_rx #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE)
) u_uart_rx (
    .clk(clk),
    .rst_n(rst_n),

    .rx(uart_rx_pin),

    .data(rx_data),
    .data_valid(rx_valid)
);

uart_cmd_parser_v2 #(
    .MAX_LEN(8)
) u_uart_cmd_parser_v2(
    .clk(clk),
    .rst_n(rst_n),

    .rx_data(rx_data),
    .rx_valid(rx_valid),

    .cmd_time(cmd_time),
    .cmd_start(cmd_start),
    .cmd_stop(cmd_stop),
    .cmd_clear(cmd_clear),

    .cmd_unknown(cmd_unknown)
);

uart_tx #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE)
) u_uart_tx (
    .clk(clk),
    .rst_n(rst_n),

    .s_data(time_data),
    .s_valid(time_valid),

    .tx(uart_tx_pin),
    .s_ready(time_ready)
);

stopwatch_core #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ)
) u_stopwatch_core (
    .clk(clk),
    .rst_n(rst_n),

    .running(running),
    .clear_pulse(clear_pulse),

    .hours(hours),
    .minutes(minutes),
    .seconds(seconds),
    .centis(centis)
);

endmodule
