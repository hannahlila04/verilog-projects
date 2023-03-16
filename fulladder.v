// Verilog code for a four-bit full adder

module top (SW, LEDR);

	input [9:0] SW;
	output [9:0] LEDR;
	wire [3:0] w1;
	
	assign LEDR[9] = w1[3];

   part2 u1(.a(SW[7:4]), .b(SW[3:0]), .c_in(SW[8]), .c_out(w1), .s(LEDR[3:0]));

endmodule // top

// module for full adder subcircuit 
module fulladder (a, b, c_in, s, c_out);
    input a, b, c_in;
    output s, c_out;

    assign s = a ^ b ^ c_in;
    assign c_out = ((a ^ b) & c_in) | (a & b);

endmodule // fulladder 

// module instantiating four instances of full adder
module part2(a, b, c_in, s, c_out);
    input [3:0] a, b;
    input c_in;
    output [3:0] s, c_out;

    fulladder bit0 (a[0], b[0], c_in, s[0], c_out[0]);
    fulladder bit1 (a[1], b[1], c_out[0], s[1], c_out[1]);
    fulladder bit2 (a[2], b[2], c_out[1], s[2], c_out[2]);
    fulladder bit3 (a[3], b[3], c_out[2], s[3], c_out[3]);

endmodule // part2
