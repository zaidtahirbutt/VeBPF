module call_handler(clk, rst, func, stb, r1, r2, r3, r4, r5, ret, IP4_led, IPv6_led, pkt_err_led, ack, err);

// -------Input-------
input [63:0] func;
input clk, stb;
input rst;
input [63:0] r1, r2, r3, r4, r5;

// -------Output-------
output reg [63:0] ret;
output reg IP4_led, IPv6_led, pkt_err_led;
output reg ack, err;

// -------Memory-------
wire [63:0] address;		// = r1; // r1 is used for address for reading and writing
assign address = r1; 		// r1 is used for address for reading and writing

wire [63:0] data_r;		  	// read data is returned to r0 register

wire [63:0] data_w;			// = r2;  // r2 is used for data for data writing 
assign data_w = r2;  		// r2 is used for data for data writing 

reg write_enable;

wire we;		// = write_enable;
assign we = write_enable;

// memory #(.data_size(64), .address_size(5)) call_handler_mem(.address(address[4:0]), .data_in(data_w), .data_out(data_r), .write_enable(we), .clk(clk));
ram64_memory_v1 #(
	// .data_size(64), 
	.DATA_SIZE(64), 
	// .address_size(5)
	.ADDRESS_SIZE(5)
) 
call_handler_mem(
	.clk(clk),
	.rst(rst),
	.address(address[4:0]), 
	.data_in(data_w), 
	.data_out(data_r), 
	.write_enable(we) 
);

reg pause;

// -------Sync Logic-------
always @(posedge clk) begin
	if(rst) begin
		ret <= 0;
	    ack <= 0;
	    err <= 0;
	    IP4_led <= 0;
	    IPv6_led <= 0;
	    pkt_err_led <= 0;
	    write_enable <= 0;
	    pause <= 0;
	end else begin
		if (stb) begin
			case(func)
				// Extension to set IP4, IPv6 or packet error LED based on R1 bits 0 - 2
				64'hff000001: begin
					IP4_led <= r1[0];
					IPv6_led <= r1[1];
					pkt_err_led <= r1[2];
					ack <= 1;
				end

				// Extension to store some values
				64'hff000002: begin
					if (~write_enable) begin
						write_enable <= 1;

					end else begin
						if (~pause) begin
							pause <= 1;
						end else begin
							pause <= 0;
							write_enable <= 0;
							ack <= 1;
						end
					end
				end

				// Extension to read values from store
				64'hff000003: begin
					if (~pause) begin
						pause <= 1;
					end else begin
						ret <= data_r;
						pause <= 0;
						ack <= 1;
					end
				end
				
				// Else throw an err
				default: begin
					err <= 1;
					ack <= 1;
				end
			endcase
		end else begin
			ack <= 0;
			err <= 0;
		end
	end
end


endmodule