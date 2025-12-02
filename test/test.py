# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


H_DISPLAY = 640
H_FRONT = 16
H_SYNC = 96
H_BACK = 48
H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK  # 800

V_DISPLAY = 480
V_FRONT = 10
V_SYNC = 2
V_BACK = 33
V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK  # 525


async def initialize_dut(dut):
    """Drive default values and apply reset."""
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)


@cocotb.test()
async def test_hsync_timing(dut):
    """Verify HSYNC pulse width and horizontal counter wrap."""
    clock = Clock(dut.clk, 40, units="ns")  # ~25 MHz
    cocotb.start_soon(clock.start())

    await initialize_dut(dut)

    # Initial state after reset release
    assert int(dut.hpos.value) == 0
    assert int(dut.vpos.value) == 0
    assert dut.hsync.value == 1
    assert dut.vsync.value == 1
    assert dut.display_on.value == 1
    assert dut.uio_out.value == 0
    assert dut.uio_oe.value == 0

    # One full line worth of cycles to check HSYNC window and wrap
    for _ in range(H_TOTAL):
        await ClockCycles(dut.clk, 1)
        hpos = int(dut.hpos.value)
        hsync_expected_low = H_DISPLAY + H_FRONT <= hpos < H_DISPLAY + H_FRONT + H_SYNC
        if hsync_expected_low:
            assert dut.hsync.value == 0
        else:
            assert dut.hsync.value == 1

    # After one full line, hpos should wrap and vpos should increment
    assert int(dut.hpos.value) == 0
    assert int(dut.vpos.value) == 1


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
        assert dut.vsync.value == 0, f"VSYNC not low at vpos {int(dut.vpos.value)}"
        await ClockCycles(dut.clk, H_TOTAL)

    # After VSYNC window, VSYNC should return high
    assert dut.vsync.value == 1

    # Confirm counters continue to advance in the active display region of the next frame
    await ClockCycles(dut.clk, H_TOTAL * (V_BACK + 1))
    assert int(dut.vpos.value) == 0
    assert int(dut.hpos.value) == 0
    assert dut.display_on.value == 1
