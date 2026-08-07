# ----------------------------------------------------------------------------
# Clock (Onboard 100MHz Oscillator) - MATCHED to VHDL 'clock'
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN Y9 [get_ports {clock}]
create_clock -period 10.000 -name CLK -waveform {0.000 5.000} [get_ports clock]

# ----------------------------------------------------------------------------
# OLED Display (Bank 13 - 3.3V)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN U10   [get_ports {oled_dc}]
set_property PACKAGE_PIN U9    [get_ports {oled_res}]
set_property PACKAGE_PIN AB12  [get_ports {oled_sclk}]
set_property PACKAGE_PIN AA12  [get_ports {oled_sdin}]
set_property PACKAGE_PIN U11   [get_ports {oled_vbat}]
set_property PACKAGE_PIN U12   [get_ports {oled_vdd}]

# ----------------------------------------------------------------------------
# Reset Switch (Slide Switch SW0) - MATCHED to VHDL 'reset'
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN F22 [get_ports {reset}]       ; # Changed from rst to reset

# ----------------------------------------------------------------------------
# Directional Buttons (Bank 34 - 1.8V)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS18 } [get_ports {btn_down}]; # "BTND"
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS18 } [get_ports {btn_left}]; # "BTNL"
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS18 } [get_ports {btn_right}]; # "BTNR"
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS18 } [get_ports {btn_up}];    # "BTNU"

# ----------------------------------------------------------------------------
# IOSTANDARD Voltage Settings (Explicit Port Assignments)
# ----------------------------------------------------------------------------
set_property IOSTANDARD LVCMOS33 [get_ports {clock}]
set_property IOSTANDARD LVCMOS33 [get_ports {reset}]
# ----------------------------------------------------------------------------
# User LEDs - Bank 33
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN T22 [get_ports {leds[0]}];  # "LD0" (Maps to btn_up)
set_property PACKAGE_PIN T21 [get_ports {leds[1]}];  # "LD1" (Maps to btn_down)
set_property PACKAGE_PIN U22 [get_ports {leds[2]}];  # "LD2" (Maps to btn_left)
set_property PACKAGE_PIN U21 [get_ports {leds[3]}];  # "LD3" (Maps to btn_right)

set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]

# OLED Display Pins (Bank 13 - 3.3V)
set_property IOSTANDARD LVCMOS33 [get_ports {oled_dc oled_res oled_sclk oled_sdin oled_vbat oled_vdd}]

# Directional Buttons (Bank 34 - 1.8V)
set_property IOSTANDARD LVCMOS18 [get_ports {btn_up btn_down btn_left btn_right}]


