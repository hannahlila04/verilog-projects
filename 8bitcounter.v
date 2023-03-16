// Verilog code implementing an 8-bit synchronous counter

module part1(Clock, Enable, Clear_b, CounterValue);
    input Clock, Enable, Clear_b;
    output [7:0] CounterValue;
    wire w0, w1, w2, w3, w4, w5, w6;

    // 1st bit
    toggle u0(Clock, Enable, Clear_b, CounterValue[0]);
    assign w0 = (CounterValue[0] * Enable);

    // 2nd bit
    toggle u1(Clock, w0, Clear_b, CounterValue[1]);
    assign w1 = (CounterValue[1] * w0);

    // 3rd bit
    toggle u2(Clock, w1, Clear_b, CounterValue[2]);
    assign w2 = (CounterValue[2] * w1);    

    // 4th bit
    toggle u3(Clock, w2, Clear_b, CounterValue[3]);
    assign w3 = (CounterValue[3] * w2);  

    // 5th bit
    toggle u4(Clock, w3, Clear_b, CounterValue[4]);
    assign w4 = (CounterValue[4] * w3);  

    // 6th bit
    toggle u5(Clock, w4, Clear_b, CounterValue[5]);
    assign w5 = (CounterValue[5] * w4);  

    // 7th bit
    toggle u6(Clock, w5, Clear_b, CounterValue[6]);
    assign w6 = (CounterValue[6] * w5);  

    // 8th bit
    toggle u7(Clock, w6, Clear_b, CounterValue[7]);        

endmodule // part1

module toggle(Clock, Enable, Clear_b, Q);
    input Clock, Enable, Clear_b;
    output reg Q;

    always @(posedge Clock) 
    begin 
        if ( Clear_b == 1'b0 ) 
            Q <= 0;
        else 
            if ( Enable == 1'b1 )
                Q <= ~Q;
            else 
                Q <= Q;
    end

endmodule // toggle


    