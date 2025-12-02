## How it works

### Overview
Black Hole Visualization on TinyTapeout — this project renders a stylized black hole (inspired by Interstellar's Gargantua) on a 640×480 VGA output using the TinyTapeout ASIC shuttle. The Verilog top level `tt_um_vga_example` drives sync, RGB outputs, and an animated "UW" logo while fitting within SkyWater 130 nm area limits.

### Visual components and draw order
The visualization is composed of three primary geometric layers rendered in a strict order to fake 3D depth on a 2D plane, plus an animated logo:
1. **Accretion Disk (Front/Back halves):** A flattened glowing ring of matter. The bottom half passes in front of the shadow; the top half sits behind it.
2. **Shadow (Event Horizon):** A pure black circle at the center that masks anything behind it.
3. **Halo (Lensed Disk):** A circular ring behind the shadow representing light bent over/under the sphere.
4. **"UW" Logo:** A floating text element that interacts with the gravity well and respects the depth rules above.

### Mathematical implementation
1. **Coordinate System** — screen coordinates are re-centered to the display midpoint so all math is local to (0,0):
   * \(dx = x_{px} - 320\)
   * \(dy = y_{px} - 240\)
2. **Geometric Metrics** — to avoid sin/cos, only squared distances are used:
   * Circular metric: \(r^2_{\text{circ}} = dx^2 + dy^2\) for the shadow and halo.
   * Flattened elliptical metric: \(r^2_{\text{flat}} = dx^2 + 16 \cdot dy^2\) (implemented as `dy_sq << 4`) to squash the disk vertically for perspective.
3. **Rendering Logic & Doppler Shift** — the disk color depends on horizontal position:
   * Left side (\(dx < 0\)): bright yellow/orange (approaching the observer).
   * Right side (\(dx > 0\)): dark red (receding).
4. **3D Depth Sorting ("Interstellar" look)** — depth is derived from Y:
   * If \(dy > 4\) (bottom half), the accretion disk draws over the shadow.
   * If \(dy < 4\) (top half), the shadow occludes the disk. The halo renders only when not hidden.

### Animation logic ("The Falling Logo")
The "UW" logo is driven by frame counter bits acting as a simple state machine:
1. **Slide In (0–2 s):** The logo slides from off-screen (\(Y = -32\)) to a hovering position (\(Y = 20\)).
2. **Hover/Wait (2–6 s):** It locks in place above the event horizon.
3. **Event Horizon Crossing (6 s+):** It accelerates downward (\(Y \propto t^2\)) into the shadow, disappearing before the cycle resets.

### Optimization note: removed star field
An experimental dynamic star field using `star_hash = ((star_x * 433) ^ (star_y * 389)) * 251;` introduced three additional multipliers. With the two large multipliers already required for \(dx^2\) and \(dy^2\), utilization jumped from ~88% to 129%, exceeding TinyTapeout limits. Removing the stars returned the design to a safe area budget while preserving the core black hole animation.

## How to test
1. **RTL simulation:** From `test/`, run `make -B` to drive the cocotb testbench against `tt_um_vga_example`.
2. **Gate-level (optional):** After hardening, place `gate_level_netlist.v` in `test/` and run `make -B GATES=yes`.
3. **On hardware:** Connect the TinyVGA PMOD (mapping `{hsync,B0,G0,R0,vsync,B1,G1,R1}`) to a VGA monitor and supply the ~25 MHz clock/reset per TinyTapeout harness. You should see the animated black hole with falling "UW" text.

## External hardware
* VGA monitor or capture device.
* TinyVGA-compatible PMOD for RGB/sync breakout.
