`default_nettype none // disable implicit nets to reduce some types of bugs
// ===================================================================
// Module Name: earEEG_prototype_top()
// ===================================================================
// This module is
// - Top module that receive(send) input(output) signals from(to) outside
// - Top module that control & generate other modules and signals
// ===================================================================

module earEEG_prototype_top(
	input  wire [ 7:0] hi_in,
	output wire [ 1:0] hi_out,
	inout  wire [15:0] hi_inout,
	inout  wire        hi_aa,
	
	output wire        hi_muxsel,
	
	input  wire        sys_clk_p,
	input  wire        sys_clk_n,
	output wire [ 7:0] led,

	input  wire [4:0] data_ins, // 입력 데이터 신호 5개 (nextout, ctrl1~4)
	output wire [7:0] outputs,  // 출력 신호 8개 (fch)
	output wire [7:0] debug_out
   );
	
	assign hi_muxsel  = 1'b0; // 변경하지 말 것
	wire sys_clk;
	IBUFGDS osc_clk(.O(sys_clk), .I(sys_clk_p), .IB(sys_clk_n)); // sys_clk 생성
	
   wire [4:0] data_ins_FPGA;
   IBUF IBUF_data_ins4(.O(data_ins_FPGA[4]), .I(data_ins[4]));
   IBUF IBUF_data_ins3(.O(data_ins_FPGA[3]), .I(data_ins[3]));
   IBUF IBUF_data_ins2(.O(data_ins_FPGA[2]), .I(data_ins[2]));
   IBUF IBUF_data_ins1(.O(data_ins_FPGA[1]), .I(data_ins[1]));
   IBUF IBUF_data_ins0(.O(data_ins_FPGA[0]), .I(data_ins[0]));

   wire [15:0] outputs_FPGA;
   OBUF OBUF_outputs7(.O(outputs[7]), .I(outputs_FPGA[7]));
   OBUF OBUF_outputs6(.O(outputs[6]), .I(outputs_FPGA[6]));
   OBUF OBUF_outputs5(.O(outputs[5]), .I(outputs_FPGA[5]));
   OBUF OBUF_outputs4(.O(outputs[4]), .I(outputs_FPGA[4]));
   OBUF OBUF_outputs3(.O(outputs[3]), .I(outputs_FPGA[3]));
   OBUF OBUF_outputs2(.O(outputs[2]), .I(outputs_FPGA[2]));
   OBUF OBUF_outputs1(.O(outputs[1]), .I(!outputs_FPGA[1]));
   OBUF OBUF_outputs0(.O(outputs[0]), .I(outputs_FPGA[0]));

   OBUF OBUF_debug7(.O(debug_out[7]), .I(r_debug_out[7]));
   OBUF OBUF_debug6(.O(debug_out[6]), .I(r_debug_out[6]));
   OBUF OBUF_debug5(.O(debug_out[5]), .I(r_debug_out[5]));
   OBUF OBUF_debug4(.O(debug_out[4]), .I(r_debug_out[4]));
   OBUF OBUF_debug3(.O(debug_out[3]), .I(r_debug_out[3]));
   OBUF OBUF_debug2(.O(debug_out[2]), .I(r_debug_out[2]));
   OBUF OBUF_debug1(.O(debug_out[1]), .I(r_debug_out[1]));
   OBUF OBUF_debug0(.O(debug_out[0]), .I(r_debug_out[0]));
   

   //==================================================
	// Debugging
   //--------------------------------------------------
	reg [7:0] r_debug_out;

	initial begin
		r_debug_out <= 0;
	end

   wire Fi_wrclk, Fi_rdclk, Fi_wren, Fi_rden, Fi_full, Fi_empty, Fo_wrclk, Fo_rdclk, Fo_wren, Fo_rden, Fo_full, Fo_empty;

	always @(*) begin
      case (HI_wi02[3:0])
      4'd0: begin // LOAD_G, READ_G, fch_G, fadc_G
         r_debug_out <= {1'b0, outputs_FPGA[4], outputs_FPGA[5], 2'b00, outputs_FPGA[6], outputs_FPGA[7], 1'b0};
      end
      4'd1: begin // in_ext, rst_n, previn_ori, fdata_G
         r_debug_out <= {1'b0, outputs_FPGA[0], !outputs_FPGA[1], 2'b00, outputs_FPGA[2], outputs_FPGA[3], 1'b0};
      end
      4'd2: begin // sys_clk, reset, previn, ti_clk
         r_debug_out <= {1'b0, sys_clk, HI_ti40[0], 2'b00, HI_ti40[1], ti_clk, 1'b0};
      end
      4'd3: begin // LOAD_G, READ_G, rst_n, previn_ori
         r_debug_out <= {1'b0, outputs_FPGA[4], outputs_FPGA[5], 2'b00, !outputs_FPGA[1], outputs_FPGA[2], 1'b0};
      end
      4'd4: begin // fadc_G, fdata_G, rst_n, previn_ori
         r_debug_out <= {1'b0, outputs_FPGA[7], outputs_FPGA[3], 2'b00, !outputs_FPGA[1], outputs_FPGA[2], 1'b0};
      end
      4'd5: begin // fadc_G, fdata_G, LOAD_G, READ_G
         r_debug_out <= {1'b0, outputs_FPGA[7], outputs_FPGA[3], 2'b00, outputs_FPGA[4], outputs_FPGA[5], 1'b0};
      end
      4'd6: begin // previn_ori, fdata_G, LOAD_G, READ_G
         r_debug_out <= {1'b0, outputs_FPGA[2], outputs_FPGA[3], 2'b00, outputs_FPGA[4], outputs_FPGA[5], 1'b0};
      end
      default: begin //  
         r_debug_out <= 0;
      end
      endcase
   end
   
   //==================================================

   //==================================================
   // API signals
   //--------------------------------------------------
	// Target interface bus:
	wire        ti_clk;
	wire [30:0] ok1;
	wire [16:0] ok2;

   //--------------------------------------------------
	// LED
	assign led = (HI_wi00[8+:8]) ^ 8'hff; // LED: L = on, H = off

   //--------------------------------------------------
	// Endpoint connections:
	wire [15:0] HI_wi00; // [15:8]: previn
	wire [15:0] HI_wi01;
	wire [15:0] HI_wi02; // debug
   wire [15:0] HI_wi03; 
   wire [15:0] HI_wi04; // clk 주파수 변경

	wire [15:0] HI_wo20, HI_wo21, HI_wo22, HI_wo23, HI_wo24, HI_wo25, HI_wo26, HI_wo27; // Pipe 데이터 개수 전달
	
	wire [15:0] HI_ti40; // [0]: reset, [1]: previn  [2]: None, [3]: data out on/off

   wire        poA0_en, poA1_en, poA2_en, poA3_en, poA4_en, poA5_en, poA6_en, poA7_en;
	wire [15:0] HI_poA0, HI_poA1, HI_poA2, HI_poA3, HI_poA4, HI_poA5, HI_poA6, HI_poA7; // pipe out



   //--------------------------------------------------
	// Instantiate the okHost and connect endpoints.
   parameter [3:0] NN = 4'd15;
	wire [17*NN-1:0]  ok2x;
	okHost okHI(
		.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
		.ok1(ok1), .ok2(ok2));

	okWireOR # (.N(NN)) wireOR (ok2, ok2x);

	okWireIn     wi00(.ok1(ok1),                           .ep_addr(8'h00), .ep_dataout(HI_wi00));
	okWireIn     wi01(.ok1(ok1),                           .ep_addr(8'h01), .ep_dataout(HI_wi01));
	okWireIn     wi02(.ok1(ok1),                           .ep_addr(8'h02), .ep_dataout(HI_wi02));
	okWireIn     wi03(.ok1(ok1),                           .ep_addr(8'h03), .ep_dataout(HI_wi03));
	okWireIn     wi04(.ok1(ok1),                           .ep_addr(8'h04), .ep_dataout(HI_wi04));

	okWireOut    wo20(.ok1(ok1), .ok2(ok2x[ 0*17 +: 17 ]), .ep_addr(8'h20), .ep_datain(HI_wo20));
   okWireOut    wo21(.ok1(ok1), .ok2(ok2x[ 1*17 +: 17 ]), .ep_addr(8'h21), .ep_datain(HI_wo21));
   okWireOut    wo22(.ok1(ok1), .ok2(ok2x[ 2*17 +: 17 ]), .ep_addr(8'h22), .ep_datain(HI_wo22));
   okWireOut    wo23(.ok1(ok1), .ok2(ok2x[ 3*17 +: 17 ]), .ep_addr(8'h23), .ep_datain(HI_wo23));
   okWireOut    wo24(.ok1(ok1), .ok2(ok2x[ 4*17 +: 17 ]), .ep_addr(8'h24), .ep_datain(HI_wo24));
   okWireOut    wo25(.ok1(ok1), .ok2(ok2x[ 5*17 +: 17 ]), .ep_addr(8'h25), .ep_datain(HI_wo25));
   okWireOut    wo26(.ok1(ok1), .ok2(ok2x[ 6*17 +: 17 ]), .ep_addr(8'h26), .ep_datain(HI_wo26));

	okTriggerIn  ti40(.ok1(ok1),                           .ep_addr(8'h40), .ep_clk(sys_clk), .ep_trigger(HI_ti40));

	okPipeOut poA0(.ok1(ok1), .ok2(ok2x[ 7*17 +: 17 ]), .ep_addr(8'hA0), .ep_read(poA0_en), .ep_datain(HI_poA0));
	okPipeOut poA1(.ok1(ok1), .ok2(ok2x[ 8*17 +: 17 ]), .ep_addr(8'hA1), .ep_read(poA1_en), .ep_datain(HI_poA1));
	okPipeOut poA2(.ok1(ok1), .ok2(ok2x[ 9*17 +: 17 ]), .ep_addr(8'hA2), .ep_read(poA2_en), .ep_datain(HI_poA2));
	okPipeOut poA3(.ok1(ok1), .ok2(ok2x[10*17 +: 17 ]), .ep_addr(8'hA3), .ep_read(poA3_en), .ep_datain(HI_poA3));
	okPipeOut poA4(.ok1(ok1), .ok2(ok2x[11*17 +: 17 ]), .ep_addr(8'hA4), .ep_read(poA4_en), .ep_datain(HI_poA4));
	okPipeOut poA5(.ok1(ok1), .ok2(ok2x[12*17 +: 17 ]), .ep_addr(8'hA5), .ep_read(poA5_en), .ep_datain(HI_poA5));
	okPipeOut poA6(.ok1(ok1), .ok2(ok2x[13*17 +: 17 ]), .ep_addr(8'hA6), .ep_read(poA6_en), .ep_datain(HI_poA6));
	okPipeOut poA7(.ok1(ok1), .ok2(ok2x[14*17 +: 17 ]), .ep_addr(8'hA7), .ep_read(poA7_en), .ep_datain(HI_poA7));


//    reg [9:0] r_count392; // 256kHz
//    reg new_clk_check;

//    initial begin
//       new_clk_check = 0;
//       r_count392 = 0;
// 	end

//   always @(posedge sys_clk or negedge outputs_FPGA[1]) begin // 256kHz
//       if (!outputs_FPGA[1]) begin
//          new_clk_check <= 0;
//          r_count392 <= 0;
//       end
//       else begin
//          if (r_count392 == 9'd392) begin
//             r_count392 <= 9'd1;
//             new_clk_check <= ~new_clk_check;
//          end
//          else begin
//             r_count392 <= r_count392 + 1'b1;
//          end
//      end
//    end

   FIFO_in_out3 u_FIFO_in_out_NEXTOUT( // NEXTOUT: fdata, READ, {4'b0,14'b0,data[1:0]}
      .debug({Fi_wrclk, Fi_rdclk, Fi_wren, Fi_rden, Fi_full, Fi_empty, Fo_wrclk, Fo_rdclk, Fo_wren, Fo_rden, Fo_full, Fo_empty}),
      // .debug2(HI_wo21),
      .ti_clk(ti_clk),
      .FPGA_CLK(sys_clk_div_sync[1]),
      .data_CLK(outputs_FPGA[3]),
      .RST(!outputs_FPGA[1]),
      .fifo_trig(HI_ti40[3]),
      .din(data_ins_FPGA[0]),
      // .din(new_clk_check),
      .rd_en_OkPipeOut(poA0_en),
      .data_trig(outputs_FPGA[5]),
      .rd_data_cnt_FIFO_out(HI_wo20),
      .dout(HI_poA0)
   );


   // Main Clock 바꾸기
   wire       sys_clk_real;
   wire [13:0] sys_clk_dec;
   reg  [12:0] sys_clk_div;
   reg  [12:0] sys_clk_div_sync;
   initial begin
      sys_clk_div <= 13'b0;
      sys_clk_div_sync <= 13'b0;
   end
   always @(posedge sys_clk) begin
      sys_clk_div[0] <= ~sys_clk_div[0];
      sys_clk_div_sync <= sys_clk_div;
   end
   genvar idx_clk;
   generate
      for (idx_clk = 0; idx_clk < 12; idx_clk = idx_clk + 1) begin : gen_main_clks
         always @(posedge sys_clk_div[idx_clk]) begin
            sys_clk_div[idx_clk + 1] <= ~sys_clk_div[idx_clk + 1];
         end
      end
   endgenerate

   assign sys_clk_dec  = {sys_clk_div_sync, sys_clk};
   assign sys_clk_real = sys_clk_dec[HI_wi02[7:4]]; 


	//==================================================
	// Call Main Module
	//==================================================
	earEEG_prototype earEEG_prototype_u(
   .sys_clk(sys_clk),   // 200MHz system CLK
   .reset(HI_ti40[0]),   // Reset trigger
   .previn(HI_ti40[1]), // Previn trigger
   .previn_code(HI_wi00[7:0]),
   .outputs(outputs_FPGA)
   );

endmodule