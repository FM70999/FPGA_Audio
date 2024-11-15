# URBANA BOARD CONSTRAINTS V2I1 1/3/2023 
# clk input is from the 100 MHz oscillator on Urbana board
#create_clock -period 10.000 -name gclk [get_ports clk_100MHz]
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {clk}]

# On-board Slide Switches
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS25} [get_ports {SW[0]}]

# PWM audio out signals
#set_property -dict {PACKAGE_PIN B13 IOSTANDARD LVCMOS33} [get_ports {SPKL}]
set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS33} [get_ports {pwm_out}]

# PWM Microphone signals
set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVCMOS33} [get_ports {MIC_CLK}]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports {pdm_in}]