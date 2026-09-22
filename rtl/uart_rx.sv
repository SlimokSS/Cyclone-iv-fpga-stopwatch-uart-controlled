module uart_rx #(
    parameter CLK_FREQ_HZ = 50000000,
    parameter BAUD_RATE = 115200
) (
    input logic clk,
    input logic rst_n,

    input logic rx,

    output logic [7:0] data,
    output logic data_valid
);

localparam int CLK_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
localparam int HALF_BIT = CLK_PER_BIT / 2;

logic [7:0] data_reg;

logic [$clog2(CLK_PER_BIT) - 1: 0] baud_cnt;

logic [2:0] bit_index;

logic baud_done;
logic half_done;

assign half_done = (baud_cnt == HALF_BIT - 1);
assign baud_done = (baud_cnt == CLK_PER_BIT - 1);

typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
} state_t;

state_t state, state_n;

logic rx_meta;
logic rx_sync;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= state_n;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_meta <= 1'b1;
        rx_sync <= 1'b1;
    end else begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_cnt <= '0;
    end else if (state == IDLE) begin
        baud_cnt <= '0;
    end else if ((state == START) && half_done) begin
        baud_cnt <= '0;
    end else if (((state == DATA) || (state == STOP)) && baud_done) begin
        baud_cnt <= '0;
    end else begin
        baud_cnt <= baud_cnt + 1'b1;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_index <= '0;
    end else if ((state == DATA) && baud_done) begin
        if (bit_index == 3'd7) begin
            bit_index <= '0;
        end else begin
            bit_index <= bit_index + 1'b1;
        end 
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data <= '0;
        data_reg <= '0;
        data_valid <= 1'b0;
    end else begin
        data_valid <= 1'b0;
        if ((state == DATA) && baud_done) begin
            data_reg[bit_index] <= rx_sync;
        end
        if ((state == STOP) && baud_done && rx_sync) begin
            data_valid <= 1'b1;
            data <= data_reg;
        end
    end
end

always_comb begin

    state_n = state;

    case (state)
    
    IDLE: begin
        if (!rx_sync) state_n = START;
    end

    START: begin
        if (half_done) begin
            if (!rx_sync) begin
                state_n = DATA;
            end else begin
                state_n = IDLE;
            end
        end
    end

    DATA: begin
        if (baud_done && bit_index == 3'd7) state_n = STOP; 
    end

    STOP: begin
        if (baud_done) state_n = IDLE;
    end

    default: begin
        state_n = IDLE;
    end

    endcase
end

endmodule