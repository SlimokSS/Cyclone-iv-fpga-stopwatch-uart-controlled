module uart_tx #(
    parameter int CLK_FREQ_HZ = 50000000,
    parameter int BAUD_RATE = 115200
) (
    input logic clk,
    input logic rst_n,

    input logic [7:0] s_data,
    input logic s_valid,

    output logic tx,
    output logic s_ready
);

logic baud_tick;

logic [7:0] data_reg;

logic [2:0] bit_index;

logic fire;

logic baud_enable;

assign fire = s_valid && s_ready;

typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
} state_t;

state_t state, state_n;

assign baud_enable = (state != IDLE);

baud_tick_gen #(
    .CLK_FREQ_HZ(15625),
    .BAUD_RATE(36)
) u_baud_tick_gen (
    .clk(clk),
    .rst_n(rst_n),
    .enable(baud_enable),

    .tick(baud_tick)
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= state_n;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_reg <= '0;
        bit_index <= '0;
    end else begin
        if (fire) data_reg <= s_data;
        if ((state == DATA) && baud_tick) begin
            if (bit_index == 3'd7)
                bit_index <= '0;
            else
                bit_index <= bit_index + 1'b1;
        end
    end
end

always_comb begin
    tx = 1'b1;
    s_ready = 1'b0;
    state_n = state;

    case (state)

        IDLE: begin
            tx = 1'b1;
            s_ready = 1'b1;
            if (fire) begin
                state_n = START;
            end
        end

        START: begin
            tx = 1'b0;
           
            if(baud_tick) state_n = DATA;
        end

        DATA: begin
            tx = data_reg[bit_index];
            if ((bit_index == 3'd7) && baud_tick) state_n = STOP;
        end

        STOP: begin
            tx = 1'b1;
            s_ready = baud_tick;
            if(baud_tick) begin
                if (fire) begin
                    state_n = START;
                end else begin
                    state_n = IDLE;
                end
            end
        end

        default: begin
            tx = 1'b1;
            s_ready = 1'b0;
            state_n = IDLE;
        end

    endcase
end

endmodule