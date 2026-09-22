module stopwatch_core #(
    parameter int CLK_FREQ_HZ = 50000000
) (
    input logic clk,
    input logic rst_n,

    input logic running,
    input logic clear_pulse,
    
    output logic [4:0] hours,
    output logic [5:0] minutes,
    output logic [5:0] seconds,
    output logic [6:0] centis
);

logic tick_10ms;

logic [4:0] live_hours;
logic [5:0] live_minutes;
logic [5:0] live_seconds;
logic [6:0] live_centis;

tick_gen #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .TICK_HZ(100)
) u_tick_gen ( 
    .clk(clk),
    .rst_n(rst_n),
    .en(running),

    .tick(tick_10ms)
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        live_centis <= 7'd0;
        live_seconds <= 6'd0;
        live_minutes <= 6'd0;
        live_hours <= 5'd0;
    end else if (clear_pulse) begin
        live_centis <= 7'd0;
        live_seconds <= 6'd0;
        live_minutes <= 6'd0;
        live_hours <= 5'd0;
    end else if (tick_10ms) begin
        if (live_centis == 7'd99) begin
            live_centis <= 7'd0;

            if (live_seconds == 6'd59) begin
                live_seconds <= 6'd0;

                if (live_minutes == 6'd59) begin
                    live_minutes <= 6'd0;

                    if (live_hours == 5'd23) begin
                        live_hours <= 5'd0;
                    end else begin
                        live_hours <= live_hours + 1'b1;
                    end

                end else begin
                    live_minutes <= live_minutes + 1'b1;
                end

            end else begin
                live_seconds <= live_seconds + 1'b1;
            end

        end else begin
            live_centis <= live_centis + 1'b1;
        end
    end
end

always_comb begin
    centis = live_centis;
    seconds = live_seconds;
    minutes = live_minutes;
    hours = live_hours;
end

endmodule