module time_response_gen (
    input logic clk,
    input logic rst_n,
    input logic cmd_time,

    input logic [4:0] hours,
    input logic [5:0] minutes,
    input logic [5:0] seconds,
    input logic [6:0] centis,
    
    input logic m_ready,

    output logic [7:0] m_data,
    output logic m_valid
);

logic [4:0] snap_hours;
logic [5:0] snap_minutes;
logic [5:0] snap_seconds;
logic [6:0] snap_centis;

logic [7:0] data [12:0];

logic [3:0] index;

logic fire;

assign fire = m_valid && m_ready;

assign data[0] = 8'h30 + (snap_hours / 10);
assign data[1] = 8'h30 + (snap_hours % 10);

assign data[2] = 8'h3A;

assign data[3] = 8'h30 + (snap_minutes / 10);
assign data[4] = 8'h30 + (snap_minutes % 10);

assign data[5] = 8'h3A;

assign data[6] = 8'h30 + (snap_seconds / 10);
assign data[7] = 8'h30 + (snap_seconds % 10);

assign data[8] = 8'h2E;

assign data[9] = 8'h30 + (snap_centis / 10);
assign data[10] = 8'h30 + (snap_centis %10);

assign data[11] = 8'h0D;
assign data[12] = 8'h0A;

assign m_data = data[index];

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        snap_hours <= '0;
        snap_minutes <= '0;
        snap_seconds <= '0;
        snap_centis <= '0;
    end else begin
        if (cmd_time && !m_valid) begin
            snap_hours <= hours;
            snap_minutes <= minutes;
            snap_seconds <= seconds;
            snap_centis <= centis;
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m_valid <= 1'b0;
    end else begin
        if (cmd_time && !m_valid) m_valid <= 1'b1;
        if (fire && (index == 4'd12)) m_valid <= 1'b0;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        index <= '0;
    end else begin 
        if (cmd_time && !m_valid) begin
            index <= '0;
        end else if (fire && (index < 12)) begin
            index <= index + 1'b1;
        end 
    end
end

endmodule
