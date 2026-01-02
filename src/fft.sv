`timescale 1ns / 10ps

module fft_8 #(
    parameter DATA_WIDTH = 16
)(
	input logic 	clk,
	input logic 	rst,
	input logic		start_fft,
	input logic signed [DATA_WIDTH-1:0] inp_real[0:7],
 	input logic signed [DATA_WIDTH-1:0] inp_imag[0:7],
 	output logic signed [DATA_WIDTH-1:0] out_real[0:7],
 	output logic signed [DATA_WIDTH-1:0] out_imag[0:7],
 	output logic completed
  );

  localparam signed [DATA_WIDTH-1:0] twiddle_real[0:3] = {16'sd256, 16'sd181, 16'sd0, -16'sd181};
  localparam signed [DATA_WIDTH-1:0] twiddle_imag[0:3] = {16'sd0, -16'sd181, -16'sd256, -16'sd181};
  
  
  logic signed [DATA_WIDTH-1:0] X_real[0:7];
  logic signed [DATA_WIDTH-1:0] X_imag[0:7];
  logic signed [DATA_WIDTH-1:0] X_real_prev[0:7];
  logic signed [DATA_WIDTH-1:0] X_imag_prev[0:7];
  

task automatic multiply(
  input 	logic signed [DATA_WIDTH-1:0] real_a,
  input 	logic signed [DATA_WIDTH-1:0] imag_a,
  input 	logic signed [DATA_WIDTH-1:0] real_b,
  input 	logic signed [DATA_WIDTH-1:0] imag_b,
  output 	logic signed [DATA_WIDTH-1:0] out_r,
  output 	logic signed [DATA_WIDTH-1:0] out_i
);

	logic signed [31:0] temp_r, temp_i;
	begin
	temp_r = (real_a * real_b - imag_a * imag_b);
	temp_i = (real_a * imag_b + real_b * imag_a);
	out_r = temp_r >>> 8; // Adjust back to 8-bit Q1.7
	out_i = temp_i >>> 8;
	end
endtask


task print_array(input logic signed [15:0] arr[0:7], input string name);
  for (int i = 0; i < 8; i++) begin
    $display("%s[%0d] = %0d", name, i, arr[i]);
  end
endtask

always_comb begin
	if(!rst) 
      completed = 1'b0;
	else if (start_fft) begin
      completed = 1'b0;
     
      // STAGE 1: 2 Point FFT

      X_real[0] = inp_real[0] + inp_real[4];
      X_real[1] = inp_real[0] - inp_real[4];
      X_real[2] = inp_real[2] + inp_real[6];
      X_real[3] = inp_real[2] - inp_real[6];
      X_real[4] = inp_real[1] + inp_real[5];
      X_real[5] = inp_real[1] - inp_real[5];
      X_real[6] = inp_real[3] + inp_real[7];
      X_real[7] = inp_real[3] - inp_real[7];
		
      X_imag[0] = inp_imag[0] + inp_imag[4];
      X_imag[1] = inp_imag[0] - inp_imag[4];
      X_imag[2] = inp_imag[2] + inp_imag[6];
      X_imag[3] = inp_imag[2] - inp_imag[6];
      X_imag[4] = inp_imag[1] + inp_imag[5];
      X_imag[5] = inp_imag[1] - inp_imag[5];
      X_imag[6] = inp_imag[3] + inp_imag[7];
      X_imag[7] = inp_imag[3] - inp_imag[7];
      
      X_real_prev = X_real;
      X_imag_prev = X_imag;

     print_array(X_real, "Stage 1");

     //	STAGE 2: 4 Point FFT
        
      multiply(X_real[3], X_imag[3], twiddle_real[2], twiddle_imag[2], X_real_prev[3], X_imag_prev[3]);
      multiply(X_real[7], X_imag[7], twiddle_real[2], twiddle_imag[2], X_real_prev[7], X_imag_prev[7]);
    
      X_real[0] = X_real_prev[0] + X_real_prev[2];
      X_real[1] = X_real_prev[1] + X_real_prev[3];
      X_real[2] = X_real_prev[0] - X_real_prev[2];
      X_real[3] = X_real_prev[1] - X_real_prev[3];
      X_real[4] = X_real_prev[4] + X_real_prev[6];
      X_real[5] = X_real_prev[5] + X_real_prev[7];
      X_real[6] = X_real_prev[4] - X_real_prev[6];
      X_real[7] = X_real_prev[5] - X_real_prev[7];
        
      X_imag[0] = X_imag_prev[0] + X_imag_prev[2];
      X_imag[1] = X_imag_prev[1] + X_imag_prev[3];
      X_imag[2] = X_imag_prev[0] - X_imag_prev[2];
      X_imag[3] = X_imag_prev[1] - X_imag_prev[3];
      X_imag[4] = X_imag_prev[4] + X_imag_prev[6];
      X_imag[5] = X_imag_prev[5] + X_imag_prev[7];
      X_imag[6] = X_imag_prev[4] - X_imag_prev[6];
      X_imag[7] = X_imag_prev[5] - X_imag_prev[7];
      
      X_real_prev = X_real;
	    X_imag_prev = X_imag;

    	// Stage 3: 8 Point FFT
    
      multiply(X_real[5], X_imag[5], twiddle_real[1], twiddle_imag[1], X_real_prev[5], X_imag_prev[5]);
      multiply(X_real[6], X_imag[6], twiddle_real[2], twiddle_imag[2], X_real_prev[6], X_imag_prev[6]);
      multiply(X_real[7], X_imag[7], twiddle_real[3], twiddle_imag[3], X_real_prev[7], X_imag_prev[7]);
    
      X_real[0] = X_real_prev[0] + X_real_prev[4];
      X_real[1] = X_real_prev[1] + X_real_prev[5];
      X_real[2] = X_real_prev[2] + X_real_prev[6];
      X_real[3] = X_real_prev[3] + X_real_prev[7];
      X_real[4] = X_real_prev[0] - X_real_prev[4];
      X_real[5] = X_real_prev[1] - X_real_prev[5];
      X_real[6] = X_real_prev[2] - X_real_prev[6];
      X_real[7] = X_real_prev[3] - X_real_prev[7];

      X_imag[0] = X_imag_prev[0] + X_imag_prev[4];
      X_imag[1] = X_imag_prev[1] + X_imag_prev[5];
      X_imag[2] = X_imag_prev[2] + X_imag_prev[6];
      X_imag[3] = X_imag_prev[3] + X_imag_prev[7];
      X_imag[4] = X_imag_prev[0] - X_imag_prev[4];
      X_imag[5] = X_imag_prev[1] - X_imag_prev[5];
      X_imag[6] = X_imag_prev[2] - X_imag_prev[6];
      X_imag[7] = X_imag_prev[3] - X_imag_prev[7];
		
      
      out_real = X_real;
  	  out_imag = X_imag;

  completed = 1'b1;
  $display("Execution done!");

   end
end
endmodule
