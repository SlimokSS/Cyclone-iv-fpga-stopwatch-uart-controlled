module baud_tick_gen #(
    parameter int CLK_FREQ_HZ = 15_625,
    parameter int BAUD_RATE = 36
) (
    input logic clk,
    input logic rst_n,
    input logic enable,

    output logic tick
);

localparam int ACC_W = $clog2(CLK_FREQ_HZ + BAUD_RATE + 1);

logic [ACC_W - 1:0] acc;
logic [ACC_W:0] acc_sum;

always_comb begin
    tick = 1'b0;
    acc_sum = acc + BAUD_RATE;
    if (enable && (acc_sum >= CLK_FREQ_HZ)) begin
        tick = 1'b1;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        acc <= '0;
    end else begin
            if (!enable) begin
                acc <= 1'b0;
            end else if (tick) begin
                acc <= acc_sum - CLK_FREQ_HZ;
            end else begin
                acc <= acc_sum;
            end
    end
end

endmodule
