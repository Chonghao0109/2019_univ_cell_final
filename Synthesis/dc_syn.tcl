


#Read All Files
#read_file -format verilog  ../Design_Source/multi_div.v
#read_file -format verilog  ../Design_Source/GPSDC.v
#read_file -format sverilog  

analyze -format verilog {../Design_Source/GPSDC.v ../Design_Source/multi_div.v}
elaborate GPSDC

current_design GPSDC
link



#Setting Clock Constraints
source -echo -verbose ../Design_Source/GPSDC.sdc
check_design
set high_fanout_net_threshold 0
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]



#Synthesis all design
#compile -map_effort high -area_effort high
#compile -map_effort high -area_effort high -inc
#compile_ultra

compile


write -format ddc     -hierarchy -output "GPSDC_syn.ddc"
write_sdf -version 1.0  GPSDC_syn.sdf
write -format verilog -hierarchy -output GPSDC_syn.v
report_area > area.log
report_timing -delay_type max > setup_timing.log
report_timing -delay_type min > hold_timing.log
report_qor   >  GPSDC_syn.qor
