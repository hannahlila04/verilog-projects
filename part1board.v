// Verilog code to display a box animation on the DE1_SoC VGA Display

// iColour is the colour for the box
//
// oX, oY, oColour and oPlot should be wired to the appropriate ports on the VGA controller
//

// Some constants are set as parameters to accommodate the different implementations
// X_SCREEN_PIXELS, Y_SCREEN_PIXELS are the dimensions of the screen
//       Default is 160 x 120, which is size for fake_fpga and baseline for the DE1_SoC vga controller
// CLOCKS_PER_SECOND should be the frequency of the clock being used.

module part2
	(
		CLOCK_50,						//	On Board 50 MHz
		SW,
		LEDR,
		KEY,							// On Board Keys
		// The ports below are for the VGA output
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input	CLOCK_50;				//	50 MHz
	input	[3:0]   KEY;					
	input   [9:0]   SW;
	input   [9:0]   LEDR;
		// KEY[0] iResetn
		// KEY[1] iPlotBox 
		// KEY[2] iBlack
		// KEY[3] iLoadX
		// SW[6:0] iXY_Coord
		// SW[9:7] iColour

	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire done;

	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;

    wire x_enable;
    wire y_enable;
    wire black_enable;
    wire reset_enable;
    wire [5:0] count;
    wire [7:0] iX;
    wire [6:0] iY;
    wire Enable;
    wire [5:0] frameCounter;
   
	// Create an Instance of a VGA controller
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.

	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";

   xCounter X0(.iClock(CLOCK_50), .oX(iX), .Enable(Enable), .iResetn(KEY[0]));

   yCounter Y0(.iClock(CLOCK_50), .oY(iY), .Enable(Enable), .iResetn(KEY[0]));

   delayCounter F0(.iClock(CLOCK_50), .iResetn(KEY[0]), .oNewFrame(oNewFrame));

   frameCounter B0(.iClock(CLOCK_50), .iResetn(KEY[0]), .oNewFrame(oNewFrame), .frameCounter(frameCounter), .Enable(Enable));
   
   control C0(.iColour(SW[9:7]), .iResetn(KEY[0]), .iClock(iClock), .oPlot(writeEn), .x_enable(x_enable), .y_enable(y_enable), 
              .black_enable(black_enable), .count(count), .reset_enable(reset_enable), .oNewFrame(oNewFrame), .frameCounter(frameCounter));

   datapath D0(.iClock(CLOCK_50), .iResetn(KEY[0]), .iColour(iColour), .oPlot(writeEn), 
               .x_enable(x_enable), .y_enable(y_enable), .black_enable(black_enable), 
               .reset_enable(reset_enable), .iX(iX), .iY(iY), .oX(x), .oY(y), .oColour(colour), .count(count));
	
endmodule

module control(iColour, iResetn, oPlot, iClock, x_enable, y_enable, black_enable, count, reset_enable, oNewFrame, frameCounter);

    input iClock, iResetn, oNewFrame;
    input [2:0] iColour;
    input [5:0] count;
    input [5:0] frameCounter;

    output reg oPlot, x_enable, y_enable, black_enable, reset_enable;

    reg [4:0] current_state, next_state;

    localparam  S_RESET           = 5'd1,
                S_DRAW            = 5'd2,
                S_FRAMEBUFFER     = 5'd3,
                S_ERASE           = 5'd4,
				S_UPDATE		  = 5'd5;

    // Next state logic aka our state table

    /* working out FSM states
    
    One frame -> draw box, clear box, shift oX by X_BOXSIZE, shift oY by Y_BOXSIZE ( add until oX == X_SCREEN then subtract - same for Y )
    between draw and clear we have to wait ( 4 seconds = 5000 * 4 clock cycles - 16 (drawing box) - 7 (clearing box) - this time we can clear in only the box coords )

    CYCLE BREAKDOWN:
      1. S_START // cycle to return to if we want to reset -> sets oX oY back to 0 0
      2. S_DRAW // 
      3. S_FRAMECOUNT -- need to figure out how long to stay on cycle
      4. S_CLEAR
      5. S_UPDATE // set dirH, dir (if countX == 160 dirX = !dirX, same for Y ), update 
   
    */

    // iColour,iResetn,iClock,oX,oY,oColour,oPlot,oNewFrame inputs and outputs for this lab 
    /*         Cycles for State Table:
                S_RESET           = 5'd1,
                S_DRAW            = 5'd2,
                S_FRAMEBUFFER     = 5'd3,
                S_ERASE           = 5'd4,
				S_UPDATE		  = 5'd5; */

    always@(*)
    begin: state_table
            case (current_state)
                S_RESET: next_state = iResetn ?  S_DRAW : S_RESET;
                S_DRAW:  begin 
                    if ( count <= 6'd15 )
                        next_state = S_DRAW;
                    else next_state = S_FRAMEBUFFER;  
                end
                S_FRAMEBUFFER: begin 
                    if ( frameCounter <= 6'd12 )
                        next_state = S_FRAMEBUFFER;
                    else next_state = S_ERASE; // how many cycles to wait until next frame
                end
                S_ERASE: begin
                    if ( count <= 6'd15 )
                        next_state = S_ERASE;
                    else next_state = S_UPDATE;
                end
                S_UPDATE: next_state = S_DRAW;
            default:     next_state = S_UPDATE;
        endcase
    end // state_table

 // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0

        x_enable = 1'b0;
        y_enable = 1'b0;
        reset_enable = 1'b0;
        oPlot = 1'b0;
        black_enable = 1'b0;

        case (current_state)
            S_RESET: begin
                reset_enable = 1'b1;
            end
            S_DRAW: begin
                oPlot = 1'b1;               
            end
            S_ERASE: begin
                black_enable = 1'b1;
                oPlot = 1'b1;
            end
            S_UPDATE: begin 
                x_enable = 1'b1;
                y_enable = 1'b1;           
            end
        // default:    // don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
        endcase
    end // enable_signals

    // current_state registers
    always@(posedge iClock)
    begin: state_FFs
        if(!iResetn)
            current_state <= S_RESET;
		else
            current_state <= next_state;
    end // state_FFS

endmodule 

module datapath(iClock, iResetn, iColour, oPlot, x_enable, y_enable, black_enable, reset_enable, iX, iY, oX, oY, oColour, count);

    input iClock, iResetn, x_enable, y_enable, black_enable, reset_enable, oPlot;
    input [7:0] iX;
    input [6:0] iY;
    input [2:0] iColour;
    output reg [5:0] count;
    output reg [7:0] oX; 
    output reg [6:0] oY;
    output reg [2:0] oColour;

    reg [7:0] X;
    reg [6:0] Y;

    always @(posedge iClock) begin
        if ( !iResetn || reset_enable ) begin
            count <= 6'd0;
            oX <= 8'd0;
            oY <= 7'd0;
            oColour <= iColour;
            X <= 8'd0;
            Y <= 7'd0;
            // potentially frame counter
        end
        else if ( x_enable ) begin
            oX <= iX;
            X <= iX;
            oColour <= iColour;
            oY <= iY;
            Y <= iY;
        end
        else if ( oPlot ) begin
            if ( black_enable ) begin
                oColour <= 3'd0;
            end
				if ( count == 6'd16 ) begin
					  count <= 6'd0;
				end 
				else begin
					count <= count + 5'd1;
				end
			oX <= X + count[1:0];
			oY <= Y + count[3:2];
		end
    end

endmodule

module xCounter (iClock, oX, Enable, iResetn);
   parameter
     X_BOXSIZE = 8'd4,   // Box X dimension
     Y_BOXSIZE = 7'd4,   // Box Y dimension
     X_SCREEN_PIXELS = 9,  // X screen width for starting resolution and fake_fpga
     Y_SCREEN_PIXELS = 7,  // Y screen height for starting resolution and fake_fpga
     CLOCKS_PER_SECOND = 1200, // 5 KHZ for fake_fpga
     X_MAX = X_SCREEN_PIXELS - X_BOXSIZE + 1, // 0-based and account for box width
     Y_MAX = Y_SCREEN_PIXELS - Y_BOXSIZE + 1,

     FRAMES_PER_UPDATE = 15,
     PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60
	       ;
    input Enable, iClock, iResetn;
    output reg [7:0] oX;
    reg DirX;

    always @(posedge iClock) begin
        if ( !iResetn ) begin
            DirX <= 1'b0;
            oX <= 8'd0;
        end 
        if ( Enable ) begin
            if ( DirX == 1'b0 ) begin
              if ( oX == X_MAX ) begin 
                    oX <= oX - 8'd1;
                    DirX <= 1'b1;
                end
                else oX <= oX + 8'd1;
            end
            else if ( DirX == 1'b1 ) begin
              if ( oX == 8'd0 ) begin 
                    oX <= oX + 8'd1;
                    DirX <= 1'b0;
                end 
                else oX <= oX - 8'd1;
            end
        end 
    end

endmodule 

module yCounter (iClock, oY, Enable, iResetn);

   parameter
     X_BOXSIZE = 8'd4,   // Box X dimension
     Y_BOXSIZE = 7'd4,   // Box Y dimension
     X_SCREEN_PIXELS = 9,  // X screen width for starting resolution and fake_fpga
     Y_SCREEN_PIXELS = 7,  // Y screen height for starting resolution and fake_fpga
     CLOCKS_PER_SECOND = 1200, // 5 KHZ for fake_fpga
     X_MAX = X_SCREEN_PIXELS - X_BOXSIZE + 1, // 0-based and account for box width
     Y_MAX = Y_SCREEN_PIXELS - Y_BOXSIZE + 1, // at y_max -> oY would then increase three to draw

     FRAMES_PER_UPDATE = 15,
     PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60
	       ;
    input iClock, Enable, iResetn;
    output reg [6:0] oY;
    reg DirY;

    always @(posedge iClock) begin
        if ( !iResetn ) begin
            DirY <= 1'b0;
            oY <= 7'd0;
        end 
        if ( Enable ) begin
            if ( DirY == 1'b0 ) begin
              if ( oY == Y_MAX ) begin 
                    oY <= oY - 7'd1;
                    DirY <= 1'b1;
                end
                else oY <= oY + 7'd1;
            end
            else if ( DirY == 1'b1 ) begin
              if ( oY == 7'd0 ) begin 
                    oY <= oY + 7'd1;
                    DirY <= 1'b0;
                end 
                else oY <= oY - 7'd1;
            end
        end 
    end

endmodule 

module delayCounter(iClock, iResetn, oNewFrame);
    input iClock, iResetn;
    output oNewFrame;
    reg [12:0] D, Q;
    parameter CLOCKS_PER_SECOND = 1200;
    parameter PULSES_PER_SIXTIETH_SECOND = (CLOCKS_PER_SECOND / 60) - 1;

    always @( posedge iClock ) begin
        if ( !iResetn ) begin 
            D <= PULSES_PER_SIXTIETH_SECOND;
            Q <= 13'b0;
        end 
        else if ( Q == 13'b0 ) begin
            Q <= D; end
        else 
            Q <= Q - 1;
    end

    assign oNewFrame = ( Q == 13'b0 && iResetn != 1'b0 ) ? 1'b1 : 1'b0;

endmodule

module frameCounter(iClock, iResetn, oNewFrame, frameCounter, Enable);
    input iClock, iResetn, oNewFrame;
    output reg [5:0] frameCounter;
    output reg Enable;

    always @( posedge iClock ) begin
      Enable <= 1'b0;
        if ( !iResetn ) begin 
            frameCounter <= 6'b0;
        end 
        else if ( !( frameCounter <= 6'd15 ) ) begin
            frameCounter <= 6'd0;
        end
        else if ( frameCounter >= 6'd15 ) begin
            frameCounter <= 6'd0;
            Enable <= 1'b1;
        end 
        if ( oNewFrame ) begin 
            frameCounter <= frameCounter + 1;
        end 
    end
        
endmodule
