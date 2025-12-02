<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design renders a stylized black hole on a 640x480 VGA display using TinyTapeout. Screen coordinates are re-centered to the midpoint (dx = x_px − 320, dy = y_px − 240) and squared-distance metrics drive all geometry, avoiding expensive trigonometry. The circular metric (r2_circ = dx² + dy²) draws the shadow and halo, while the flattened metric (r2_flat = dx² + 16·dy²) shapes the accretion disk with an edge-on perspective. Color uses a Doppler-inspired rule: pixels on the left (dx < 0) glow bright yellow/orange, and pixels on the right (dx > 0) render dark red. A y-based priority gives the Interstellar-like depth effect—when dy > 4 the disk draws over the shadow, and when dy < 4 the shadow occludes the disk. A state machine animates the floating "UW" logo through slide-in, hover, and gravity-driven fall phases before looping. The earlier "dynamic stars" experiment was removed to fit TinyTapeout’s tight area constraints after multiplier-heavy hashing spiked utilization beyond limits.

## How to test

Program the design onto a TinyTapeout board and connect its VGA output to a 640x480-capable display. After reset, observe the layered accretion disk, shadow, and halo with the animated "UW" logo cycling through slide-in, hover, and fall phases. No additional configuration is required.

## External hardware

- VGA monitor or adapter capable of 640x480 input.
