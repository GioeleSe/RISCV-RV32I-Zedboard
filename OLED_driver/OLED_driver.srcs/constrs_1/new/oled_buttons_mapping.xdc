# ----------------------------------------------------------------------------
# Clock (Onboard 100MHz Oscillator)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN Y9 [get_ports {clk}]
create_clock -period 10.000 -name CLK -waveform {0.000 5.000} [get_ports clk]

# ----------------------------------------------------------------------------
# OLED Display (Bank 13 - 3.3V)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN U10  [get_ports {oled_dc}]
set_property PACKAGE_PIN U9   [get_ports {oled_res}]
set_property PACKAGE_PIN AB12 [get_ports {oled_sclk}]
set_property PACKAGE_PIN AA12 [get_ports {oled_sdin}]
set_property PACKAGE_PIN U11  [get_ports {oled_vbat}]
set_property PACKAGE_PIN U12  [get_ports {oled_vdd}]

# ----------------------------------------------------------------------------
# Reset Switch (Slide Switch SW0)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN F22 [get_ports {rst}]        ; # Changed back to match VHDL 'rst'

# ----------------------------------------------------------------------------
# Directional Buttons (Bank 34 - 1.8V)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN R16 [get_ports {btn_down}]   ; # "BTND"
set_property PACKAGE_PIN N15 [get_ports {btn_left}]   ; # "BTNL"
set_property PACKAGE_PIN R18 [get_ports {btn_right}]  ; # "BTNR"
set_property PACKAGE_PIN T18 [get_ports {btn_up}]     ; # "BTNU"

# ----------------------------------------------------------------------------
# IOSTANDARD Voltage Settings
# ----------------------------------------------------------------------------
set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 13]]
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 34]]
set_property IOSTANDARD LVCMOS25 [get_ports -of_objects [get_iobanks 35]]