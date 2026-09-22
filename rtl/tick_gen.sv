module tick_gen #(
    parameter int CLK_FREQ_HZ = 50000000,
    parameter int TICK_HZ = 100
)(
    input logic clk,
    input logic rst_n,
    input logic en,

    output logic tick
);

localparam int DIVISOR = CLK_FREQ_HZ / TICK_HZ;
localparam int CNT_W = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

logic [CNT_W - 1:0] clk_cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        tick <= 1'b0;
        clk_cnt <= '0;
    end else begin
        tick <= 1'b0;
        if(!en) begin
            clk_cnt <= '0;
        end else if (clk_cnt == DIVISOR - 1) begin
            tick <= 1'b1;
            clk_cnt <= '0;
        end else begin
            clk_cnt <= clk_cnt + 1'b1;
        end
    end
end
endmodule
