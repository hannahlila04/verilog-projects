// Verilog program for a 2-to-1 mux using the 7404 (NOT), 7432 (OR), and 7408 (AND) gates 

module mux2to1 (x, y, s, m);
    input x; //select 0
    input y; //select 1
    input s; //select signal
    output m; //output

wire w1, w2, w3;

// instantiating the first module
v7404 U1 (.pin1(s), .pin2(w1));

// instantiating the second module
v7432 U2 (.pin1(x), .pin2(w1), .pin3(w2), .pin4(y), .pin5(s), .pin6(w3));

// instantiating the third module
v7408 U3 (.pin1(w2), .pin2(w3), .pin3(m));

endmodule // mux2to1

// declaring the module for the NOT gate
module v7404 (input pin1, pin3, pin5, pin9, pin11, pin13,
			  output pin2, pin4, pin6, pin8, pin10, pin12);

assign pin2 = !pin1;
assign pin4 = !pin3;
assign pin6 = !pin5;
assign pin8 = !pin9;
assign pin10 = !pin11;
assign pin12 = !pin13;

endmodule // v7404 

// declaring the module for the OR gate
module v7432 (input pin1, pin2, pin4, pin5, pin13, pin12, pin10, pin9,
			  output pin3, pin6, pin11, pin8);

assign pin3 = pin1 | pin2;
assign pin6 = pin4 | pin5;
assign pin11 = pin13 | pin12;
assign pin8 = pin10 | pin11;

endmodule // v7432

// declaring the module for the AND gate
module v7408 (input pin1, pin2, pin4, pin5, pin13, pin12, pin10, pin9,
			  output pin3, pin6, pin11, pin8);

assign pin3 = pin1 & pin2;
assign pin6 = pin4 & pin5;
assign pin11 = pin13 & pin12;
assign pin8 = pin10 & pin11;

endmodule // v7408