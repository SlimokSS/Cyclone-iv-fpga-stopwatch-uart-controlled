module uart_cmd_parser_v2 #(
    parameter int MAX_LEN = 8
) (
    input logic clk,
    input logic rst_n,

    input logic [7:0] rx_data,
    input logic rx_valid,

    output logic cmd_time,
    output logic cmd_start,
    output logic cmd_stop,
    output logic cmd_clear,

    output logic cmd_unknown
);

logic [7:0] buffer [0:MAX_LEN-1];
logic [$clog2(MAX_LEN+1) - 1:0] length;
logic line_overflow;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin

        cmd_time <= 1'b0;
        cmd_start <= 1'b0;
        cmd_stop <= 1'b0;
        cmd_clear <= 1'b0;
        
        cmd_unknown <= 1'b0;

        length <= '0;

    end else begin
        
        cmd_time <= 1'b0;
        cmd_start <= 1'b0;
        cmd_stop <= 1'b0;
        cmd_clear <= 1'b0;
        
        cmd_unknown <= 1'b0;

        if(rx_valid) begin

            if((rx_data == 8'h0D) || (rx_data == 8'h0A)) begin

                length <= '0;
                
                if (!line_overflow) begin
                    case (length)

                        4: begin
                            case ({buffer[0], buffer[1], buffer[2], buffer[3]})
                                32'h54494D45: cmd_time <= 1'b1; // TIME
                                32'h53544F50: cmd_stop <= 1'b1; // STOP
                                default: cmd_unknown <= 1'b1;
                            endcase
                        end

                        5: begin
                            case ({buffer[0], buffer[1], buffer[2], buffer[3], buffer[4]})
                                40'h5354415254: cmd_start <= 1'b1; // START
                                40'h434C454152: cmd_clear <= 1'b1; // CLEAR
                                default: cmd_unknown <= 1'b1;
                            endcase
                        end
                        default: begin
                            if (length != '0) cmd_unknown <= 1'b1;
                        end
                    endcase
                end else cmd_unknown <= 1'b1;

            end else if (length < MAX_LEN) begin
                buffer[length] <= rx_data;
                length <= length + 1'b1;
            end
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        line_overflow <= 1'b0;
    end else begin
        if ((length == MAX_LEN ) && (rx_valid) && !((rx_data == 8'h0D) || (rx_data == 8'h0A))) begin
            line_overflow <= 1'b1;
        end
        if (((rx_data == 8'h0D) || (rx_data == 8'h0A)) && rx_valid) line_overflow <= 1'b0;
    end
end

endmodule
