#create_clock -period 50MHz -name clk [get_ports {clk}]
derive_pll_clocks -create_base_clock
#if {$::quartus(nameofexecutable) == "quartus_fit"} {
#set_max_delay -from *symbolsPerTransfer* -to *i1_outstandingTransactions* -10.000
#set_min_delay -from *symbolsPerTransfer* -to *i1_outstandingTransactions* -10.000

##set_max_delay -to [get_clocks clk] 20
#}

