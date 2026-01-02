`include "FIFO.sv"
`include "FFT.sv"

`timescale 1ns/10ps

module fft_fifo_top #(
    parameter DATA_WIDTH = 16
)(
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      write_en_external,
    input  logic                      read_en_external,
    input  logic signed [DATA_WIDTH-1:0] data_in_external,
    output logic signed [DATA_WIDTH-1:0] data_out_external
);
 
typedef enum logic [2:0] {
  IDLE,
  DELAY1,
  LOAD,
  DELAY2,
  START_FFT,
  WAIT_FFT_DONE,
  WRITE_OUTPUT
} state_t;

state_t current_state, next_state;

// ============== FIFO1 signals ==============
    logic signed [DATA_WIDTH-1:0] fifo_in_data_out;
    logic fifo_in_full, fifo_in_empty, read_en_internal;

// ============== FIFO2 signals ==============
    logic signed [DATA_WIDTH-1:0] fifo_out_data_in;
    logic fifo_out_full, fifo_out_empty, write_en_internal;

// ============== FFT signals 1 ==============
    logic signed [DATA_WIDTH-1:0] fft_in_real_1[0:7];
    logic signed [DATA_WIDTH-1:0] fft_in_imag_1[0:7];
    logic signed [DATA_WIDTH-1:0] fft_out_real_1[0:7];
    logic signed [DATA_WIDTH-1:0] fft_out_imag_1[0:7];
    logic fft_start_1, fft_done_1;

// ============== FFT signals 2 ==============
    logic signed [DATA_WIDTH-1:0] fft_in_real_2[0:7];
    logic signed [DATA_WIDTH-1:0] fft_in_imag_2[0:7];
    logic signed [DATA_WIDTH-1:0] fft_out_real_2[0:7];
    logic signed [DATA_WIDTH-1:0] fft_out_imag_2[0:7];
    logic fft_start_2, fft_done_2;

// ============== Common Signals ==================
	logic fft_done;

// ============== counters ==============
  logic [4:0] sample_count;
  logic [4:0] output_count;
  logic [4:0] delay_count;
  
// ============== AXI Handshake ===============
  logic in_valid;
  logic in_ready;
  logic signed [DATA_WIDTH-1:0] in_data;
  logic out_valid;
  logic out_ready;
  logic signed [DATA_WIDTH-1:0] out_data;

// =================== FIFO IN Instantiations ===================

fifo #(
	.DATA_WIDTH(DATA_WIDTH),
	.ADDR_WIDTH(5)
) fifo_in (
	.clk(clk),
	.rst(rst),
	.write_en(write_en_external),
	.read_en(read_en_internal),
	.data_in(data_in_external),
	.data_out(fifo_in_data_out),
	.full(fifo_in_full),
	.empty(fifo_in_empty)
);

// ===================== FFT Instantiation 1 =====================

fft_8 #(
	.DATA_WIDTH(DATA_WIDTH)
) u_fft_1 (
	.clk(clk),
	.rst(rst),
  	.start_fft(fft_start_1),
	.inp_real(fft_in_real_1),
	.inp_imag(fft_in_imag_1),
	.out_real(fft_out_real_1),
	.out_imag(fft_out_imag_1),
	.completed(fft_done_1)
);

// ===================== FFT Instantiation 2 =====================

fft_8 #(
	.DATA_WIDTH(DATA_WIDTH)
) u_fft_2 (
	.clk(clk),
	.rst(rst),
  	.start_fft(fft_start_2),
	.inp_real(fft_in_real_2),
	.inp_imag(fft_in_imag_2),
	.out_real(fft_out_real_2),
	.out_imag(fft_out_imag_2),
	.completed(fft_done_2)
);

// ===================== FIFO Instantiations =====================

fifo #(
.DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(5)
) fifo_out (
	.clk(clk),
	.rst(rst),
	.write_en(write_en_internal),
	.read_en(read_en_external),
	.data_in(fifo_out_data_in),
	.data_out(data_out_external),
	.full(fifo_out_full),
	.empty(fifo_out_empty)
);
  
// =================== State Change ====================

always_ff @(posedge clk or negedge rst) begin
	if (!rst)
		current_state <= IDLE;
	else
		current_state <= next_state;
end
  
// ===================== FSM Logic =====================

always_comb begin
  read_en_internal = 1'b0;
  next_state = current_state;
  unique case(current_state)
	
    IDLE: begin
      if(!fifo_in_empty) begin
        read_en_internal = 1'b1;
        next_state = DELAY1;
      end 
      else
          read_en_internal = 1'b0;
    end
    
    DELAY1: begin
      read_en_internal = 1'b1;
      if(delay_count > 0)
        next_state = LOAD;
    end
    
    LOAD: begin
      read_en_internal = 1'b1;
      if (sample_count == 31)
        next_state = DELAY2;
    end
    
    DELAY2: begin
      if(delay_count > 1)
        next_state = START_FFT;
    end
    
    START_FFT: begin
      next_state = WAIT_FFT_DONE;
    end
    
    WAIT_FFT_DONE: begin
      if(fft_done)
        next_state = WRITE_OUTPUT;
    end
    
    WRITE_OUTPUT: begin
      if(fifo_out_full)
        next_state = IDLE;
    end
	
	default: next_state = IDLE;
  endcase
end

// ===================== Control Logic =====================
    
always_ff @(posedge clk or negedge rst) begin
  if(!rst) begin
    sample_count <= 0;
    output_count <= 0;
    fft_start_1 <= 0;
    fft_start_2 <= 0;
  end
  
  else begin
	case (current_state)
      IDLE: begin
        sample_count <= 0;
        output_count <= 0;
        fft_start_1 <= 0;
        fft_start_2 <= 0;
        delay_count <= 0;
      end
      
      DELAY1: begin
        delay_count = delay_count + 1;
      end
      
      LOAD: begin
        delay_count <= 0;
        $display("Entered LOAD");
        if(in_valid && in_ready) begin
          if (sample_count < 8)
            fft_in_real_1[sample_count] <= in_data;   
			
          else if (sample_count < 16 && sample_count > 7)
            fft_in_imag_1[sample_count - 8] <= in_data;
          
	      else if (sample_count > 15 && sample_count < 24)
             fft_in_real_2[sample_count - 16] <= in_data;   
          
		    else
            fft_in_imag_2[sample_count - 24] <= in_data;

          sample_count <= sample_count + 1;
          $display("FIFO to FFT %f", in_data);
        end
      end

      DELAY2: begin
        delay_count = delay_count + 1;
      end
      
      START_FFT: begin
        fft_start_1 <= 1;
        fft_start_2 <= 1;		
        output_count <= 0;
        delay_count <= 0;
      end
      
      WAIT_FFT_DONE: begin
        if(fft_done) begin
          fft_start_1 <= 0;
          fft_start_2 <= 0;
          write_en_internal <= 1;    
        end 
      end
      
      WRITE_OUTPUT: begin
        if(out_ready) begin
          if(output_count < 8)
            out_data <= fft_out_real_1[output_count];
			
          else if (output_count > 7 && output_count < 16)
            out_data <= fft_out_imag_1[output_count - 8];

          else if (output_count > 15 && output_count < 24)
            out_data <= fft_out_real_2[output_count - 16];

          else
            out_data <= fft_out_imag_2[output_count - 24];
			
          output_count <= output_count + 1;
        end
      end
    endcase
  end
end

// ===================== AXIS Control =====================
    
  assign in_valid = !fifo_in_empty;
  assign in_ready = (current_state == LOAD);
  assign in_data = fifo_in_data_out;

  assign out_valid = (current_state == WRITE_OUTPUT);
  assign out_ready = !fifo_out_full;
  assign fifo_out_data_in = out_data;

 
  assign fft_done = fft_done_1 && fft_done_2;

endmodule
