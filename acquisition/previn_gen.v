// `default_nettype none // disable implicit nets to reduce some types of bugs
/* ================================================================
Module Name: previn_gen()
===================================================================
This module
- generates PREVIN based on PC inputs
================================================================ */
module previn_gen (
   // in-out for interface and basic system
   input  wire       fdata_G,  // fdata_G && & R_L_state
   input  wire       rst_n,    // reset active low
   input  wire       previn_trig,
   input  wire [7:0] previn_code, 
   output wire       previn
   );

   assign previn = r_previn[r_end];

   //==================================================
   // Previn generation
   reg [8:0] r_previn;
   reg [3:0] r_count9; // count 8
   reg [3:0] r_end;

   initial begin
      r_previn <= 9'b0;
      r_count9 <= 4'd8;
      r_end    <= 4'd8;
   end

   always @(posedge previn_trig or negedge rst_n) begin
      if (!rst_n) begin
         r_previn <= 9'b0;
      end
      else begin
         r_previn <= {1'b0,previn_code};
      end
   end 

   always @(negedge fdata_G or negedge rst_n) begin
      if (!rst_n) begin
         r_count9 <= 4'd8;
         r_end    <= 4'd8;
      end
      else begin
         if (r_count9 == 4'd0) begin
            r_count9 <= r_count9;
            r_end <= 4'd8;
         end
         else begin
            r_count9 <= r_count9 - 4'b1;
            r_end <= r_end - 4'b1;
         end
      end
   end
endmodule
