`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  // Expose internal VGA timing signals for cocotb access
  // Keep these signals from being optimized away so cocotb can observe them
  (* keep *) wire hsync;
  (* keep *) wire vsync;
  (* keep *) wire activevideo;
  (* keep *) wire [9:0] x_px;
  (* keep *) wire [9:0] y_px;
  (* keep *) wire [15:0] frame_cnt;
  // Additional kept wires to preserve geometry internals
  (* keep *) wire display_on;
  (* keep *) wire [9:0] hpos;
  (* keep *) wire [9:0] vpos;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  tt_um_vga_example user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR       (VPWR),
      .VGND       (VGND),
`endif

      .ui_in      (ui_in),     // Dedicated inputs
      .uo_out     (uo_out),    // Dedicated outputs
      .uio_in     (uio_in),    // IOs: Input path
      .uio_out    (uio_out),   // IOs: Output path
      .uio_oe     (uio_oe),    // IOs: Enable path (active high: 0=input, 1=output)
      .ena        (ena),       // enable - goes high when design is selected
      .clk        (clk),       // clock
      .rst_n      (rst_n)      // not reset
  );

  // Extract VGA timing signals from uo_out port
  // uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
  assign hsync = uo_out[7];
  assign vsync = uo_out[3];

  // Tap internal geometry signals hierarchically so cocotb can sample them
  assign activevideo = user_project.activevideo;
  assign x_px       = user_project.x_px;
  assign y_px       = user_project.y_px;
  assign frame_cnt  = user_project.frame_cnt;

  // Preserve generator internals needed by tests and waveform inspection
  assign display_on = user_project.hvsync_gen.display_on;
  assign hpos       = user_project.hvsync_gen.hpos;
  assign vpos       = user_project.hvsync_gen.vpos;

endmodule
