# Base timing constraints for TinyTapeout design
# Guards around get_ports prevent empty lookups from halting STA when
# optional ports are not present in the synthesized netlist.

# Clock definition (20 ns = 50 MHz)
set clk_ports [get_ports -quiet clk]
if { [llength $clk_ports] } {
    create_clock -name clk -period 20 $clk_ports
}

# Reset is active-low; constrain as asynchronous input if present
set rst_ports [get_ports -quiet rst_n]
if { [llength $rst_ports] } {
    set_input_delay 0 -clock clk $rst_ports
    set_false_path -from $rst_ports -to [all_outputs]
}

# User input bus
set ui_in_ports [get_ports -quiet {ui_in[*]}]
if { [llength $ui_in_ports] } {
    set_input_delay 0 -clock clk $ui_in_ports
}

# Bidirectional input side
set uio_in_ports [get_ports -quiet {uio_in[*]}]
if { [llength $uio_in_ports] } {
    set_input_delay 0 -clock clk $uio_in_ports
}

# Enable pin
set ena_ports [get_ports -quiet ena]
if { [llength $ena_ports] } {
    set_input_delay 0 -clock clk $ena_ports
}

# Outputs
set uo_out_ports [get_ports -quiet {uo_out[*]}]
if { [llength $uo_out_ports] } {
    set_output_delay 0 -clock clk $uo_out_ports
}

# Bidirectional output/enable sides
set uio_out_ports [get_ports -quiet {uio_out[*]}]
if { [llength $uio_out_ports] } {
    set_output_delay 0 -clock clk $uio_out_ports
}

set uio_oe_ports [get_ports -quiet {uio_oe[*]}]
if { [llength $uio_oe_ports] } {
    set_output_delay 0 -clock clk $uio_oe_ports
}

# Basic timing exceptions: ignore paths from inputs to resets
if { [llength $rst_ports] && [llength $ui_in_ports] } {
    set_false_path -from $ui_in_ports -to $rst_ports
}
