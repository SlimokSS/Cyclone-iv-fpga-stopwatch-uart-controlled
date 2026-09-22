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

logic [1:0] cnt_hours_tens;
logic [2:0] cnt_minutes_tens;
logic [2:0] cnt_seconds_tens;
logic [3:0] cnt_centis_tens;

logic conversion_done;

logic [7:0] data [12:0];

logic [3:0] index;

logic fire;

typedef enum logic [1:0] {
    IDLE,
    CONVERT,
    SEND
} state_t;

state_t state, state_n;

assign fire = m_valid && m_ready;

assign data[2] = 8'h3A;

assign data[5] = 8'h3A;

assign data[8] = 8'h2E;

assign data[11] = 8'h0D;

assign data[12] = 8'h0A;

assign m_data = data[index];

always_comb begin
    m_valid = 1'b0;
    state_n = state;
    case (state)
        IDLE: begin
            m_valid = 1'b0;
            if (cmd_time) state_n = CONVERT;
        end

        CONVERT: begin
            m_valid = 1'b0;
            if (conversion_done) state_n = SEND;
        end

        SEND: begin
            m_valid = 1'b1;
            if ((index == 4'd12) && fire) state_n = IDLE;
        end
        
        default: begin
            state_n = IDLE;
            m_valid = 1'b0;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= state_n;
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin

        snap_hours <= '0;
        snap_minutes <= '0;
        snap_seconds <= '0;
        snap_centis <= '0;

        cnt_hours_tens <= '0;
        cnt_minutes_tens <= '0;
        cnt_seconds_tens <= '0;
        cnt_centis_tens <= '0;

        conversion_done <= 1'b0;

        index <= '0;

    end else begin
        if (state == IDLE) begin

            if (cmd_time) begin
                snap_hours <= hours;
                snap_minutes <= minutes;
                snap_seconds <= seconds;
                snap_centis <= centis;
            end

            cnt_hours_tens <= '0;
            cnt_minutes_tens <= '0;
            cnt_seconds_tens <= '0;
            cnt_centis_tens <= '0;

            index <= '0;

        end

        if (state == CONVERT) begin

            conversion_done <= 1'b0;

            if(snap_hours >= 10) begin
                snap_hours <= snap_hours - 4'd10;
                cnt_hours_tens <= cnt_hours_tens + 1'b1;
            end else begin
                data[0] <= 8'h30 + cnt_hours_tens;
                data[1] <= 8'h30 + snap_hours;
            end

            if(snap_minutes >= 10) begin
                snap_minutes <= snap_minutes - 4'd10;
                cnt_minutes_tens <= cnt_minutes_tens + 1'b1;
            end else begin
                data[3] <= 8'h30 + cnt_minutes_tens;
                data[4] <= 8'h30 + snap_minutes;
            end

            if(snap_seconds >= 10) begin
                snap_seconds <= snap_seconds - 4'd10;
                cnt_seconds_tens <= cnt_seconds_tens + 1'b1;
            end else begin
                data[6] <= 8'h30 + cnt_seconds_tens;
                data[7] <= 8'h30 + snap_seconds;
            end

            if(snap_centis >= 10) begin
                snap_centis <= snap_centis - 4'd10;
                cnt_centis_tens <= cnt_centis_tens + 1'b1;
            end else begin
                data[9] <= 8'h30 + cnt_centis_tens;
                data[10] <= 8'h30 + snap_centis;
            end

            if ((snap_hours < 10) && (snap_minutes < 10) &&
            (snap_seconds < 10) && (snap_centis < 10)) conversion_done <= 1'b1;
        end

        if (state == SEND) begin
            conversion_done <= 1'b0;    
            if (fire && (index < 12)) begin
                index <= index + 1'b1;
            end
        end
    end
end

endmodule