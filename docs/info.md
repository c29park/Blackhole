## How it works

### Overview
This design renders a stylized black hole scene—loosely inspired by Interstellar's "Gargantua"—on a 640×480 VGA output within TinyTapeout's SkyWater 130 nm tile constraints. The Verilog top level `tt_um_vga_example` drives horizontal/vertical sync, RGB outputs, and an animated "UW" logo that interacts with the gravity well.

### Visual components and draw order
1. **Accretion Disk (Front/Back halves):** A flattened glowing ring that orbits the center. The bottom half renders in front of the shadow; the top half is occluded by it.
2. **Shadow (Event Horizon):** A pure black circle that masks anything behind it.
3. **Halo (Lensed Disk):** A circular band behind the shadow representing light bent over/under the sphere.
4. **"UW" Logo:** Falls toward the event horizon, respecting the depth rules above.

### Coordinate system and metrics
* Screen coordinates are re-centered to the display midpoint:
  * \(dx = x_{px} - 320\)
  * \(dy = y_{px} - 240\)
* Squared-distance metrics avoid trigonometry:
  * Circular: \(r^2_{\text{circ}} = dx^2 + dy^2\) for the shadow and halo.
  * Flattened elliptical: \(r^2_{\text{flat}} = dx^2 + 16 \cdot dy^2\) (implemented as `dy_sq << 4`) for the accretion disk perspective.

### Rendering, Doppler tint, and depth
* **Color shift:** The disk uses a Doppler-inspired tint—left side (dx < 0) is bright yellow/orange (approaching), right side (dx > 0) is deep red (receding).
* **Priority by Y depth:** If `dy > 4`, the belt draws over the shadow (front half). Otherwise the shadow occludes the belt (back half). The halo only appears when unobstructed.

### Animation logic ("falling" logo)
A frame counter advances on each VSYNC edge to drive the logo phases:
1. **Slide-in (≈0–2 s):** Logo travels from off-screen \(Y=-32\) to \(Y=20\).
2. **Hover (≈2–6 s):** Logo holds at \(Y=20\).
3. **Event-horizon crossing (≈6 s+):** Logo accelerates downward (\(Y \propto t^2\)) into the shadow before the cycle repeats.

### Optimization note: removed star field
An experimental star-field hash (`star_hash = ((star_x * 433) ^ (star_y * 389)) * 251;`) added three extra multipliers, pushing logic utilization from ~88% to ~129%. To fit TinyTapeout area limits—already hosting two large multipliers for \(dx^2\) and \(dy^2\)—the star field was removed, restoring safe utilization while keeping the core black-hole animation.

## How to test
1. **RTL simulation:** From `test/`, run `make -B` to drive the cocotb testbench against `tt_um_vga_example`.
2. **Gate-level (optional):** After hardening, place `gate_level_netlist.v` in `test/` and run `make -B GATES=yes`.
3. **On hardware:** Connect the TinyVGA PMOD (mapping `{hsync,B0,G0,R0,vsync,B1,G1,R1}`) to a VGA monitor and supply the ~25 MHz clock/reset per TinyTapeout harness. You should see the animated black hole with falling "UW" text.

## External hardware
* VGA monitor or capture device.
* TinyVGA-compatible PMOD for RGB/sync breakout.
