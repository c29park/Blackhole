## How it works
Black Hole Visualization on TinyTapeout renders a stylized black hole (inspired by Interstellar's Gargantua) on a 640×480 VGA output using the Verilog top level `tt_um_vga_example`. The design re-centers screen coordinates to (0,0) at pixel (320,240), then builds geometry from squared-distance metrics: circular \(r^2_{\text{circ}} = dx^2 + dy^2\) for the shadow/halo and flattened \(r^2_{\text{flat}} = dx^2 + 16\cdot dy^2\) for the accretion disk. Colors follow a Doppler-inspired rule—left side (dx < 0) in bright yellow/orange, right side (dx > 0) in dark red—while depth sorting uses the Y-coordinate so the bottom half of the disk (dy > 4) passes in front of the shadow and the top half sits behind it.

Visual elements draw in strict priority: front belt (bottom half of the accretion disk), shadow (event horizon) that blocks everything behind it, falling "UW" logo that respects occlusion, back belt (top half), and halo (lensed background). The logo animation cycles through slide-in, hover, and event-horizon-crossing phases driven by frame-counter bits, with downward acceleration before reset. A removed star-field experiment once used a hash `((star_x * 433) ^ (star_y * 389)) * 251;` that added three multipliers and pushed utilization from ~88% to 129%, so it was dropped to keep the design within TinyTapeout area limits while preserving the main animation.

## How to test
1. RTL simulation: From `test/`, run `make -B` to exercise the cocotb testbench against `tt_um_vga_example`.
2. Gate-level (optional): After hardening, place `gate_level_netlist.v` in `test/` and run `make -B GATES=yes`.
3. On hardware: Connect the TinyVGA PMOD mapping `{hsync,B0,G0,R0,vsync,B1,G1,R1}` to a VGA monitor and supply the ~25 MHz clock/reset per the TinyTapeout harness to view the animated black hole and falling "UW" text.

## External hardware
* VGA monitor or capture device.
* TinyVGA-compatible PMOD for RGB/sync breakout.
