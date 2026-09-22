module command_executor (
    input logic clk,
    input logic rst_n,

    input logic cmd_start,
    input logic cmd_stop,
    input logic cmd_clear,

    output logic running,
    output logic clear_pulse
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clear_pulse <= 1'b0;
        running <= 1'b0;
    end else begin
        clear_pulse <= 1'b0;
        if (cmd_clear) clear_pulse <= 1'b1;
        if (cmd_start) running <= 1'b1;
        if (cmd_stop) running <= 1'b0;
    end
end

endmodule
