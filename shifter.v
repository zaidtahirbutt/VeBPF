module shifter(clk, rst, stb, arith, left, value, shift, out, ack);

	parameter data_width = 64;

	input stb, clk, rst;
	input arith;
	input left;
	input [data_width-1:0] value;
	input [data_width-1:0] shift;

	output reg [data_width-1:0] out;
	output reg ack;

	reg state;
	reg [data_width-1:0] tmp1, tmp2;

	always @(posedge clk) begin
		if (rst) begin
			ack <= 0;
			out <= 0;
			state <= 0;
			tmp1 <= 0;
			tmp2 <= 0;
		end else begin
			if (ack) begin
				ack <= 0;
				state <= 0;
			end else if (state) begin
				if (~left & arith & value[data_width-1]) begin
					out <= tmp1 | tmp2;
				end else begin
					out <= tmp2;
				end
				ack <= 1;
			end else if (stb) begin
				if (~left) begin
					tmp1 <= ~({data_width{1'b1}} >> shift);
					tmp2 <= (value >> shift);
				end else begin
					tmp2 <= (value << shift);
				end
				state <= 1;
			end
		end
	end

endmodule