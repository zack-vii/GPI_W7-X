source $board_path/config/ports.tcl

# Add PS and AXI Interconnect
set board_preset $board_path/config/board_preset.tcl
source $sdk_path/fpga/lib/starting_point.tcl

# Add ADCs and DACs
source $sdk_path/fpga/lib/redp_adc_dac.tcl
set adc_dac_name adc_dac
add_redp_adc_dac $adc_dac_name

# Rename clocks
set adc_clk $adc_dac_name/adc_clk

# Add processor system reset synchronous to adc clock
set rst_adc_clk_name proc_sys_reset_adc_clk
cell xilinx.com:ip:proc_sys_reset:5.0 $rst_adc_clk_name {} {
  ext_reset_in $ps_name/FCLK_RESET0_N
  slowest_sync_clk $adc_clk
}

# Add config and status registers
source $sdk_path/fpga/lib/ctl_sts.tcl
add_ctl_sts $adc_clk $rst_adc_clk_name/peripheral_aresetn

# Connect LEDs
connect_port_pin led_o [get_slice_pin [ctl_pin led] 7 0]

# Connect ADC to status register
for {set i 0} {$i < [get_parameter n_adc]} {incr i} {
  connect_pins [sts_pin adc$i] adc_dac/adc[expr $i + 1]
}

## Add DAC controller
#source $sdk_path/fpga/lib/bram.tcl
#set dac_bram_name [add_bram dac]

#connect_pins adc_dac/dac1 [get_slice_pin $dac_bram_name/doutb 13 0]
#connect_pins adc_dac/dac2 [get_slice_pin $dac_bram_name/doutb 29 16]

#connect_cell $dac_bram_name {
#  web  [get_constant_pin 0 4]
#  dinb [get_constant_pin 0 32]
#  clkb $adc_clk
 # rstb $rst_adc_clk_name/peripheral_reset
#}


# Use AXI Stream clock converter (ADC clock -> FPGA clock)
set intercon_idx 0
set idx [add_master_interface $intercon_idx]
cell xilinx.com:ip:axis_clock_converter:1.1 adc_clock_converter {
  TDATA_NUM_BYTES 4
} {
  s_axis_aresetn $rst_adc_clk_name/peripheral_aresetn
  m_axis_aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
  s_axis_aclk $adc_clk
  m_axis_aclk [set ps_clk$intercon_idx]
}

# Add AXI stream FIFO to read pulse data from the PS
cell xilinx.com:ip:axi_fifo_mm_s:4.1 adc_axis_fifo {
  C_USE_TX_DATA 0
  C_USE_TX_CTRL 0
  C_USE_RX_CUT_THROUGH true
  C_RX_FIFO_DEPTH 32768
  C_RX_FIFO_PF_THRESHOLD 32760
} {
  s_axi_aclk [set ps_clk$intercon_idx]
  s_axi_aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
  S_AXI [set interconnect_${intercon_idx}_name]/M${idx}_AXI
  AXI_STR_RXD adc_clock_converter/M_AXIS
}

assign_bd_address [get_bd_addr_segs adc_axis_fifo/S_AXI/Mem0]
set memory_segment  [get_bd_addr_segs /${::ps_name}/Data/SEG_adc_axis_fifo_Mem0]
set_property offset [get_memory_offset adc_fifo] $memory_segment
set_property range  [get_memory_range adc_fifo]  $memory_segment

################################### Make all the Blocks ################################################3

create_bd_cell -type ip -vlnv PSFC:user:data_collector:1.0 data_collector_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0

##################################### Connected all the Blocks ######################################################


connect_bd_net [get_bd_pins data_collector_0/tdata] [get_bd_pins adc_clock_converter/s_axis_tdata]
connect_bd_net [get_bd_pins data_collector_0/tvalid] [get_bd_pins adc_clock_converter/s_axis_tvalid]

connect_bd_net [get_bd_pins data_collector_0/adc_clk] [get_bd_pins adc_dac/adc_clk]

connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins data_collector_0/clk_en]

connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins adc_dac/dac1] -boundary_type upper
connect_bd_net [get_bd_pins adc_dac/adc2] [get_bd_pins adc_dac/dac2] -boundary_type upper
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins data_collector_0/data_1]
connect_bd_net [get_bd_pins adc_dac/adc2] [get_bd_pins data_collector_0/data_2]
















