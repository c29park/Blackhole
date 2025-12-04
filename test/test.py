# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# ---------------------------------------------------------------------------
# VGA timing constants
# ---------------------------------------------------------------------------

H_DISPLAY = 640
H_FRONT   = 16
H_SYNC    = 96
H_BACK    = 48
H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK  # 800

V_DISPLAY = 480
V_FRONT   = 10
V_SYNC    = 2
V_BACK    = 33
V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK  # 525

# Geometry thresholds (must match Verilog localparams)
SHADOW_R2   = 7225      # r=85
BELT_IN_R2  = 10000
BELT_OUT_R2 = 85000
HALO_IN_R2  = 5000
HALO_OUT_R2 = 22000


async def initialize_dut(dut):
    """Drive default values and apply reset (for timing tests)."""
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)


# ---------------------------------------------------------------------------
# Existing timing tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_hsync_timing(dut):
    """Verify HSYNC pulse width and period."""
    clock = Clock(dut.clk, 40, units="ns")  # ~25 MHz
    cocotb.start_soon(clock.start())

    await initialize_dut(dut)

    # Initial state after reset release
    assert dut.hsync.value == 1
    assert dut.vsync.value == 1
    assert dut.uio_out.value == 0
    assert dut.uio_oe.value == 0

    # Count HSYNC low pulses to verify timing
    hsync_low_count = 0
    hsync_high_count = 0
    
    # One full line worth of cycles to check HSYNC window
    for _ in range(H_TOTAL):
        await ClockCycles(dut.clk, 1)
        if dut.hsync.value == 0:
            hsync_low_count += 1
        else:
            hsync_high_count += 1

    # HSYNC should be low for H_SYNC cycles
    assert hsync_low_count == H_SYNC, f"Expected {H_SYNC} low cycles, got {hsync_low_count}"
    # HSYNC should be high for the rest
    assert hsync_high_count == H_TOTAL - H_SYNC


@cocotb.test()
async def test_vsync_timing(dut):
    """Verify VSYNC pulse width at the expected line numbers."""
    clock = Clock(dut.clk, 40, units="ns")  # ~25 MHz
    cocotb.start_soon(clock.start())

    await initialize_dut(dut)

    # Advance to the start of the VSYNC pulse region
    lines_until_vsync = V_DISPLAY + V_FRONT
    await ClockCycles(dut.clk, H_TOTAL * lines_until_vsync)

    # VSYNC should assert low for V_SYNC lines
    for expected_line in range(V_SYNC):
        assert dut.vsync.value == 0, f"VSYNC not low at line {expected_line}"
        await ClockCycles(dut.clk, H_TOTAL)

    # After VSYNC window, VSYNC should return high
    assert dut.vsync.value == 1

    # Advance through the back porch to verify frame completion
    await ClockCycles(dut.clk, H_TOTAL * V_BACK)
    # VSYNC should still be high after back porch
    assert dut.vsync.value == 1


# ---------------------------------------------------------------------------
# Golden model helpers for geometry / pixel shader
# ---------------------------------------------------------------------------

def decode_rgb_from_uo(val: int):
    """
    Decode 2-bit R,G,B from uo_out bit layout:
      {hsync, B0, G0, R0, vsync, B1, G1, R1}
    """
    R = ((val >> 0) & 1) | (((val >> 4) & 1) << 1)
    G = ((val >> 1) & 1) | (((val >> 5) & 1) << 1)
    B = ((val >> 2) & 1) | (((val >> 6) & 1) << 1)
    return R, G, B


def golden_pixel_color(x_px: int, y_px: int, frame_cnt: int):
    """
    Software reimplementation of the black hole shader for one pixel.
    Returns (R, G, B) as 2-bit ints each (0..3).
    """

    # ---------------------------------------------------------------
    # Geometry: dx, dy and squared distances
    # ---------------------------------------------------------------
    dx = x_px - 320
    dy = y_px - 240

    dx_sq = dx * dx
    dy_sq = dy * dy

    r2_circ = dx_sq + dy_sq
    r2_flat = dx_sq + (dy_sq << 4)  # *16

    # ---------------------------------------------------------------
    # Text logic: "UW"
    # ---------------------------------------------------------------
    # frame_cnt[8] decides between static and falling
    if ((frame_cnt >> 8) & 1) == 1:
        text_y_pos = 20 + (frame_cnt & 0xFF)
    else:
        text_y_pos = 20

    in_text_y = (y_px >= text_y_pos) and (y_px < text_y_pos + 32)
    diff_y = y_px - text_y_pos
    rel_y = diff_y & 0x1F  # low 5 bits

    # Letter U: X: 292-315
    in_u_x = (x_px >= 292) and (x_px < 316)
    u_rel_x = ((x_px & 0x1F) - 4)
    draw_u = (
        in_text_y
        and in_u_x
        and (u_rel_x < 4 or u_rel_x >= 20 or rel_y >= 28)
    )

    # Letter W: X: 324-347
    in_w_x = (x_px >= 324) and (x_px < 348)
    w_rel_x = ((x_px & 0x1F) - 4)
    draw_w = (
        in_text_y
        and in_w_x
        and (
            w_rel_x < 4
            or w_rel_x >= 20
            or rel_y >= 28
            or ((w_rel_x >= 10 and w_rel_x < 14) and (rel_y >= 16))
        )
    )

    draw_text = draw_u or draw_w

    # ---------------------------------------------------------------
    # Texture logic for belt and halo
    # ---------------------------------------------------------------
    belt_tex_val = (((r2_flat >> 8) & 0xFF) - (frame_cnt & 0xFF)) & 0xFF
    belt_gap = (belt_tex_val >> 4) & 1
    belt_yellow = (belt_tex_val >> 2) & 1

    halo_tex_val = (((r2_circ >> 6) & 0xFF) - (frame_cnt & 0xFF)) & 0xFF
    halo_gap = (halo_tex_val >> 4) & 1
    halo_yellow = (halo_tex_val >> 2) & 1

    # ---------------------------------------------------------------
    # Region flags
    # ---------------------------------------------------------------
    in_shadow = (r2_circ < SHADOW_R2)
    in_belt = (r2_flat >= BELT_IN_R2) and (r2_flat <= BELT_OUT_R2)
    in_halo = (r2_circ >= HALO_IN_R2) and (r2_circ <= HALO_OUT_R2)

    belt_is_in_front = (dy > 4)

    # ---------------------------------------------------------------
    # Rendering logic (match Verilog priority)
    # ---------------------------------------------------------------
    # Default background: black
    R = 0
    G = 0
    B = 0

    # PRIORITY 1: Front belt (bottom half)
    if in_belt and belt_is_in_front:
        if belt_gap:
            R, G, B = 1, 0, 0  # Very Dim Red Gap
        elif belt_yellow:
            R, G, B = 3, 2, 0  # Yellow/Orange Ring
        else:
            R, G, B = 3, 0, 0  # Bright Blood Red

    # PRIORITY 2: Shadow
    elif in_shadow:
        R, G, B = 0, 0, 0  # Pure Black

    # PRIORITY 3: Text
    elif draw_text:
        R, G, B = 3, 3, 3  # White Text

    # PRIORITY 4: Back belt (top half)
    elif in_belt:
        if belt_gap:
            R, G, B = 1, 0, 0
        elif belt_yellow:
            R, G, B = 3, 2, 0
        else:
            R, G, B = 3, 0, 0

    # PRIORITY 5: Halo
    elif in_halo:
        if halo_gap:
            R, G, B = 1, 0, 0
        elif halo_yellow:
            R, G, B = 3, 2, 0
        else:
            R, G, B = 3, 0, 0

    # Else: background stays black

    return R, G, B


# ---------------------------------------------------------------------------
# Strong geometry test: full-frame compare using local x/y counters
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_blackhole_geometry_full_frame(dut):
    """
    Strong geometry test:
    Recreate the same (hpos, vpos) counters in Python, in lockstep with the
    clock and reset, and for every visible pixel compare hardware RGB against
    the golden model RGB.
    """
    clock = Clock(dut.clk, 40, units="ns")  # ~25 MHz
    cocotb.start_soon(clock.start())

    # Manual reset here so we can keep our local x/y counters in sync
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Local copies of hpos/vpos logic (same as in hvsync_generator)
    sim_x = 0
    sim_y = 0

    # Hold reset for 2 cycles (design hpos/vpos stay at 0)
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1  # release reset

    # Now run through one full frame worth of cycles
    num_cycles = H_TOTAL * V_TOTAL

    mismatches = 0
    checked = 0

    for _ in range(num_cycles):
        await ClockCycles(dut.clk, 1)

        # Update our local (x,y) counters in the same way as hvsync_generator
        if sim_x == H_TOTAL - 1:
            sim_x = 0
            if sim_y == V_TOTAL - 1:
                sim_y = 0
            else:
                sim_y += 1
        else:
            sim_x += 1

        # Only check visible pixels (display_on region)
        if sim_x >= H_DISPLAY or sim_y >= V_DISPLAY:
            continue

        frame_cnt = int(dut.frame_cnt.value) & 0xFFFF

        # Hardware RGB
        hw_R, hw_G, hw_B = decode_rgb_from_uo(int(dut.uo_out.value))

        # Expected RGB from golden model
        exp_R, exp_G, exp_B = golden_pixel_color(sim_x, sim_y, frame_cnt)

        checked += 1
        if (hw_R, hw_G, hw_B) != (exp_R, exp_G, exp_B):
            mismatches += 1
            if mismatches <= 10:
                dut._log.error(
                    f"Pixel mismatch at (x={sim_x}, y={sim_y}), frame_cnt={frame_cnt}: "
                    f"HW R,G,B = {hw_R},{hw_G},{hw_B} vs "
                    f"EXP R,G,B = {exp_R},{exp_G},{exp_B}"
                )

    assert mismatches == 0, f"Found {mismatches} pixel color mismatches out of {checked} checked"
