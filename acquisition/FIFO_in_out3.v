module FIFO_in_out3 (
   output wire [11:0] debug,
   output wire [15:0] debug2,

   input  wire        FPGA_CLK,          // FPGA 내부 연산 CLK (sys_clk 또는 그 division)
   input  wire        ti_clk,            // 통신 clk (Opalkelly API CLK)
   input  wire        data_CLK,          // 외부 입력 데이터 동기화 CLK (fdata)
   input  wire        RST,               // reset
   input  wire        fifo_trig,         // fifo 시작 trigger
   input  wire        din,               // input data
   input  wire        rd_en_OkPipeOut,   // output fifo rd_en (okPipeOut ep_read)
   input  wire        data_trig,         // 외부 입력 데이터 update 동기화 (read)
   output wire [15:0] rd_data_cnt_FIFO_out, // output fifo rd_count
   output wire [15:0] dout               // output data
   );

   assign debug[11] = ~data_CLK;
   assign debug[10] = FPGA_CLK;
   assign debug[ 9] = wr_en_FIFO_in;
   assign debug[ 8] = rd_en_FIFO_in;
   assign debug[ 7] = full_FIFO_in;
   assign debug[ 6] = empty_FIFO_in;
   assign debug[ 5] = FPGA_CLK;
   assign debug[ 4] = ti_clk;
   assign debug[ 3] = wr_en_FIFO_out;
   assign debug[ 2] = rd_en_FIFO_out;
   assign debug[ 1] = full_FIFO_out;
   assign debug[ 0] = empty_FIFO_out;
   assign debug2 = r_dout_rec_FPGA_in;

   //==================================================
   // FIFO control
   //--------------------------------------------------
   // PC FIFO call -> FIFO On/Off
   reg start_FIFO_in_ready;
   reg start_FIFO_in;
   initial begin
      start_FIFO_in_ready = 0;
      start_FIFO_in = 0;
   end
   always @(posedge fifo_trig) begin
      start_FIFO_in_ready <= ~start_FIFO_in_ready;
   end
   always @(posedge (data_trig && data_CLK)) begin
      if (~start_FIFO_in_ready) begin
         start_FIFO_in <= 1'b0;
      end
      else begin
         start_FIFO_in <= 1'b1;
      end
   end

   //--------------------------------------------------
   // Data in only
   wire full_FIFO_in, empty_FIFO_in; // FIFO flags (if full, empty = high)
   wire dout_FIFO_in;                // FIFO output
   wire wr_en_FIFO_in;               // write enable
   wire rd_en_FIFO_in;               // read enable

   assign wr_en_FIFO_in = start_FIFO_in && ~full_FIFO_in;

   FIFO_control u_FIFO_control( // rd_clk should be faster than wr_clk      
      .rd_clk(FPGA_CLK),
      .reset(RST),
      .empty(empty_FIFO_in),
      .rd_timing(rd_en_FIFO_in)
      );
   
	fifo_1b_1b_131072 FIFO_IC_test0( // 1bit IC in
      .rst(RST),             // 
      .wr_clk(~data_CLK),    // 
      .rd_clk(FPGA_CLK),     // 
      .din(din),             // 
      .wr_en(wr_en_FIFO_in), // 
      .rd_en(rd_en_FIFO_in), // 
      .dout(dout_FIFO_in),   // 
      // .rd_data_count(), // 
      .full(full_FIFO_in),   // 
      .empty(empty_FIFO_in)  // 
   );

   //--------------------------------------------------
   // Data processing between IN/OUT FIFOs & Make wr_en for FIFO out
   reg [15:0] r_dout_rec_FPGA_in;
   reg [ 4:0] r_count16;
   reg        start_FIFO_out;
   initial begin
      r_dout_rec_FPGA_in <= 0;
      r_count16 <= 0;
      start_FIFO_out <= 0;
   end
   always @(negedge FPGA_CLK or posedge RST) begin
      if (RST) begin
         r_dout_rec_FPGA_in <= 0;
         r_count16 <= 0;
         start_FIFO_out <= 0;
      end
      else begin
         if (rd_en_FIFO_in) begin
            r_dout_rec_FPGA_in[0] <= dout_FIFO_in;
            r_dout_rec_FPGA_in[15:1] <= r_dout_rec_FPGA_in[14:0];
            if (r_count16 == 5'd15) begin
               r_count16 <= 5'd0;
               start_FIFO_out <= 1'b1;
            end
            else begin
               r_count16 <= r_count16 + 1'b1;
               start_FIFO_out <= 0;
            end
         end
         else begin
            r_dout_rec_FPGA_in <= r_dout_rec_FPGA_in;
            r_count16 <= r_count16;
            start_FIFO_out <= 0;
         end
      end
   end
   //--------------------------------------------------
   // 

   //--------------------------------------------------
   // Data out only
   wire full_FIFO_out, empty_FIFO_out; // FIFO flags (if full, empty = high)
   wire wr_en_FIFO_out;                // write enable
   wire rd_en_FIFO_out;                // read enable

   assign wr_en_FIFO_out = start_FIFO_out && ~full_FIFO_out;

   assign rd_en_FIFO_out = rd_en_OkPipeOut;
   // assign rd_en_FIFO_out = rd_en_OkPipeOut && ~empty_FIFO_out;

   fifo_16b_16b_4194304 FIFO_FPGA_to_PC0( // 32bit pipe out, 1 transfer = 1000*128 bit
                                        // FIFO wr_depth = 8192 ~= 8sec
      .rst(RST),
      .wr_clk(FPGA_CLK),              // modified FPGA CLK (~FPGA_CLK)
      .rd_clk(ti_clk),                    // OK FrontPanel CLK
      .din(r_dout_rec_FPGA_in), // ADC raw data
      .wr_en(wr_en_FIFO_out),                 //
      .rd_en(rd_en_FIFO_out),                 //
      .dout(dout),                     // HI_poA0
      .rd_data_count(rd_data_cnt_FIFO_out),            // rd_data_count
      .full(full_FIFO_out),                   // to ensure that the FIFO is never full or empty,
      .empty(empty_FIFO_out)                  // python UI will only read a certain amount of data
                                          // when there are sufficient amount of them
   );
endmodule