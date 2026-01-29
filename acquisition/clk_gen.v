// `default_nettype none // disable implicit nets to reduce some types of bugs
/* ================================================================
Module Name: clk_gen()
===================================================================
This module
- generates CLKs based on sys_clk
================================================================ */
module clk_gen (
   // in-out for interface and basic system
   input  wire       sys_clk,  // 200MHz system clock
   input  wire       rst_n,    // reset active low
   input  wire       R_L_con,  // READ_G와 LOAD_G의 상호배타적 관계 조절
   output wire [4:0] new_clks, // generated clocks
                               // [0] fdata_G (1024kHz)
                               // [1] LOAD_G (duty 주의, on/off gate 필요)
                               // [2] READ_G (64kHz, duty 주의, on/off gate 필요)
                               // [3] fch_G (64kHz)
                               // [4] fadc_G (64kHz)
   output wire       R_L_state
   );

   assign new_clks = r_new_clks;

   //==================================================
   // Clock generation
   //--------------------------------------------------
   // Control signal
   R_L_controller m_R_L_controller(
      .rst_n(rst_n),
      .R_L_con(R_L_con),
      .fdata_G(r_new_clks[0]),
      .LOAD_G(r_new_clks[1]),
      .R_L_state(R_L_state)
   );

   // Generate sub_CLKs (counters)
   reg [9:0] r_new_clks; // 200MHz
   reg [7:0] r_count98; // 1024kHz (~1020kHz)
   reg [3:0] r_count8; // 128kHz (~127.5kHz)
   reg [4:0] r_count16; // 64kHz (~63.75kHz)
   
   initial begin
      r_new_clks = 0;
      r_count98 = 0;
      r_count8 = 0;
      r_count16 = 0;
   end

   always @(posedge sys_clk) begin // 1024kHz
         // fdata_G (always on)
         if (r_count98 == 7'd98) begin
            r_count98 <= 7'd1;
            r_new_clks[0] <= ~r_new_clks[0];
         end
         else begin
            r_count98 <= r_count98 + 1'b1;
         end
   end

   always @(negedge r_new_clks[0] or negedge rst_n) begin
      if (!rst_n) begin
         r_new_clks[4:1] <= 0;
         r_count8 <= 0;
         r_count16 <= 0;
      end

      else begin
         if (R_L_state) begin
            // LOAD_G
            if (r_count8 == 4'd8) begin
               r_count8 <= r_count8 + 1'b1;
               r_new_clks[1] <= ~r_new_clks[1];
            end
            else if (r_count8 == 4'd9) begin
               r_count8 <= 4'd2;
               r_new_clks[1] <= ~r_new_clks[1];
            end
            else begin
               r_count8 <= r_count8 + 1'b1;
            end

            // READ_G, fch_G, fadc_G
            r_count16 <= 0;
            r_new_clks[4:2] <= 0;
         end

         else begin
            // LOAD_G
            r_count8 <= 0;
            r_new_clks[1] <= 0;
         
            // READ_G, fch_G, fadc_G
            if (r_count16 == 4'd8) begin
               r_count16 <= r_count16 + 1'b1;
               r_new_clks[2] <= ~r_new_clks[2];
               r_new_clks[4:3] <= ~r_new_clks[4:3];
            end
            else if (r_count16 == 4'd9) begin
               r_count16 <= r_count16 + 1'b1;
               r_new_clks[2] <= ~r_new_clks[2];
            end
            else if (r_count16 == 5'd16) begin
               r_count16 <= r_count16 + 1'b1;
               r_new_clks[4:3] <= ~r_new_clks[4:3];
            end
            else if (r_count16 == 5'd17) begin
               r_count16 <= 2'd2;
            end
            else begin
               r_count16 <= r_count16 + 1'b1;
            end
         end
      end
   end

endmodule
