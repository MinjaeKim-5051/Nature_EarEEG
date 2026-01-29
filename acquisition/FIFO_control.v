`default_nettype none // disable implicit nets to reduce some types of bugs

/* ================================================================
Module Name: FIFO_control()
===================================================================
This module
- generates control variables for OPCODE_FIFO

================================================================ */
module FIFO_control (
   // in-out for interface and basic system
   input  wire       rd_clk,  // FIFO clock (FPGA part)
   input  wire       reset,     // HI_in1[0], reset signal from PC
   input  wire       empty,     // input FIFO is empty (read side)
   output reg        rd_timing  // read enable switch
   );
   
   //==================================================
   // Input FIFO read control
   //--------------------------------------------------
   parameter [1:0] init_rd_mode  = 2'b01, // gray code
                   begin_rd_mode = 2'b10;   

   reg [1:0] rd_state = init_rd_mode, next_rd_state = init_rd_mode;

   always @(negedge rd_clk or posedge reset) begin
      if (reset) begin
         rd_state = init_rd_mode;
      end
      else
         rd_state = next_rd_state;
   end

   always @(*) begin
      next_rd_state = rd_state;

      case (rd_state)
      //--------------------------------------------------
      init_rd_mode: begin
         if (empty) begin
            next_rd_state = init_rd_mode;
         end
         else begin
            next_rd_state = begin_rd_mode;
         end
         
         rd_timing = 0;
      end
      //--------------------------------------------------
      begin_rd_mode: begin
         if (empty) begin
            next_rd_state = init_rd_mode;
         end
         else begin
            next_rd_state = begin_rd_mode;
         end

         rd_timing = 1;
      end
      //--------------------------------------------------
      default: begin
         next_rd_state = init_rd_mode;
         rd_timing = 0;
      end
      //--------------------------------------------------
      endcase
   end
   //==================================================
endmodule
