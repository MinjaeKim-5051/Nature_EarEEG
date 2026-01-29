// `default_nettype none // disable implicit nets to reduce some types of bugs
// ================================================================
// Module Name: earEEG_prototype()
// ================================================================
// This module is
// - Top module that receive(send) input(output) signals from(to) outside
// - Top module that control & generate other modules and signals
// ================================================================

module earEEG_prototype(
   input  wire        sys_clk,   // System Clock 200MHz
   input  wire        reset,     // Active High
   input  wire        previn,    // Active High

   input  wire  [7:0] previn_code, // Used for PREVIN 

   output wire [7:0] outputs  // Outputs[7:0]
                              // : fadc_G, fch_G, READ_G, LOAD_G, fdata_G, previn, reset, in_ext
   );

   assign outputs = r_outputs_sync;
   //--------------------------------------------------
   // Sync outputs
   reg [7:0] r_outputs_sync;

   initial begin
      r_outputs_sync = 0;
   end

   always @(posedge sys_clk or negedge rst_n) begin //  delay , 
      if (!rst_n) begin
         r_outputs_sync <= 0;
      end
      else begin
         r_outputs_sync <= {(new_clks[4]),  // fadc_G
                            (new_clks[3]),  // fch_G
                            (new_clks[2]),  // READ_G
                            (new_clks[1]),  // LOAD_G
                            (new_clks[0]),  // fdata_G
                            (previn_ori),   // PREVIN
                            (rst_n),        // rst_n
                            1'b0};
      end
   end
   
   //==================================================
   // Trigger 신호 조작
   //--------------------------------------------------
   reg rst_n; // digital block들 기본이 active low
   reg r_R_L_con;

   initial begin
      rst_n <= 1'b1;
      r_R_L_con <= 1'b0;
   end

   always @(posedge reset) begin
      rst_n <= ~ rst_n;
   end

   always @(posedge previn or negedge rst_n) begin
      if (!rst_n) begin
         r_R_L_con <= 1'b0;
      end
      else begin
         r_R_L_con <= ~ r_R_L_con;
      end
   end

   //==================================================

   //==================================================
   // Control signals 생성
   //--------------------------------------------------
   wire [4:0] new_clks; // fadc_G, fch_G, READ_G, LOAD_G, fdata_G
   wire R_L_state; 
   wire previn_ori;

   clk_gen m_clk_gen(
      .sys_clk(sys_clk),
      .rst_n(rst_n),
      .new_clks(new_clks),
      .R_L_con(r_R_L_con),
      .R_L_state(R_L_state)
   );

   previn_gen m_previn_gen(
      .fdata_G(new_clks[0] & R_L_state),
      .rst_n(rst_n),         // reset active low
      .previn_trig(previn),  // previn trigger input
      .previn_code(previn_code),
      .previn(previn_ori)   // Out
   );

endmodule
