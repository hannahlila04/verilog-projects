// Verilog code implementing a counter that takes in speed (SW[0] and SW[1]) to adjust the speed of counting 

module part2(ClockIn, Reset, Speed, CounterValue);
    input ClockIn, Reset;
    input [1:0] Speed;
    output [3:0] CounterValue;
    wire [10:0] w1;
    reg [10:0] CountRate;
    wire w2; 

    // RateDivider counter counts down to - and generates an enable pulse when it reaches zero
    // RateDivider counter - if Speed changes in the middle of counting down, the RateDivider counter must continue to count down to 0 and load the new frequency after generating the enable signal
    // When RateDivider counter is reset it should be reset to the full speed value
    // CLOCK_50 gives 500 Hz with Automarker

    always @( Speed ) 
    begin
        if ( Speed == 2'b00 ) 
        begin
            CountRate <= 11'b0;
        end
        else if ( Speed == 2'b01 ) 
        begin
            CountRate <= (500 - 1);
        end
        else if ( Speed == 2'b10 ) 
        begin
            CountRate <= (1000 - 1);
        end
        else if ( Speed == 2'b11 ) 
        begin
            CountRate <= (2000 - 1);
        end
    end

    /* Speed[1]    Speed[0]    CountRate    Description
          0           0         Full        Once every clock period
          0           1         1 Hz        Once a second
          1           0         0.5 Hz      Once every two seconds
          1           1         0.25 Hz     Once every four seconds

          Table gives rate at which digits change

          Design fully synchronous circuit -> every flip flop clocked in by same ClockIn clock signal

          Use a counter called RateDivider to create the pulses at the required rates, every time RateDivider counts the appropriate number of clock pulses, a pulse is generated for one clock cycle

          Parallel load counter with appropriate starting value and count down to 0
    */

    // [Parallel Load] muxOut, [10:0] CountRate
    RateDivider u1(ClockIn, Reset, w2, CountRate, w1);

    // CountRate and ClockIn - Switch is Speed

    countFour u2(CounterValue, Reset, ClockIn, w2);

endmodule // part2

module countFour(Q, Reset, Clock, Enable); 
    input Clock, Reset, Enable;
    output reg [3:0] Q;

    always @(posedge Clock)
    begin
        if ( Reset == 1'b1 )
            Q <= 0;
        else if ( Enable == 1'b1 )
            if ( Q == 4'b1111 )
                Q <= 0;
            else 
                Q <= Q + 1;
    end

endmodule // countFour

module RateDivider(ClockIn, Reset, EnableOut, D, Q);
    input ClockIn, Reset;
    input [10:0] D;
    output reg [10:0] Q;
    output EnableOut;

    always @(posedge ClockIn)
    begin
        if ( Reset == 1'b1 )
            Q <= 0;
        else if ( Q == 11'b0 )
            Q <= D;
        else 
            Q <= Q - 1;
    end

    assign EnableOut = ( Q == 11'b0 ) ? 1'b1 : 1'b0;

endmodule // RateDivider