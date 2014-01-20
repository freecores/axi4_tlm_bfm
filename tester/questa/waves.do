configure wave -signalnamewidth 1

add wave -divider "DUV"
add wave -position end -decimal sim:/user/symbolsPerTransfer
add wave -position end -decimal sim:/user/axiMaster/outstandingTransactions
add wave -position end  sim:/user/axiMaster/axiTxState
add wave -position end  sim:/user/axiMaster/next_axiTxState

add wave -divider "Tester"
add wave -position end  sim:/user/clk
add wave -position end  sim:/user/nReset
add wave -position end  sim:/user/irq_write
add wave -position end  sim:/user/axiMaster/trigger
add wave -position end  sim:/user/axiMaster/i_trigger
add wave -position end  -hexadecimal sim:/user/prbs

# Paper publication:
#add wave -position end  sim:/user/irq_write
#add wave -position end  -hexadecimal sim:/user/axiMaster_in.tReady
#add wave -position end  -hexadecimal sim:/user/axiMaster_out.tValid
#add wave -position end  -hexadecimal sim:/user/axiMaster_out.tData
#add wave -position end  -hexadecimal sim:/user/prbs
#add wave -position end  -hexadecimal sim:/user/writeRequest.trigger
#add wave -position end  -hexadecimal sim:/user/writeResponse.trigger

add wave -position end -expand -hexadecimal sim:/user/axiMaster_in
add wave -position end -expand -hexadecimal sim:/user/axiMaster_out
#add wave -position end -expand -hexadecimal sim:/user/axiMaster/i_axiMaster_out
add wave -position end -decimal sim:/user/readRequest
add wave -position end -expand -hexadecimal sim:/user/writeRequest
add wave -position end -decimal sim:/user/readResponse
add wave -position end -expand -hexadecimal sim:/user/axiMaster/i_writeResponse
add wave -position end -expand -hexadecimal sim:/user/writeResponse
add wave -position end sim:/user/txFSM
add wave -position end sim:/user/i_txFSM

#OS-VVM solution:
#add wave -position end -unsigned -format analog-step -height 80 -scale 0.4e-17 sim:/user/axiMaster_out.tData

#LFSR solution:
add wave -position end -unsigned -format analog-step -height 80 -scale 0.18e-7 sim:/user/axiMaster_out.tData

add wave -position end  sim:/i_prbs/isParallelLoad
add wave -position end  sim:/i_prbs/loadEn
add wave -position end  sim:/i_prbs/loaded
add wave -position end  sim:/i_prbs/i_loaded
add wave -position end  sim:/i_prbs/load
add wave -position end  -hexadecimal sim:/i_prbs/d
add wave -position end  -hexadecimal sim:/i_prbs/seed
add wave -position end  -hexadecimal sim:/user/prbs

run 80 ns;

wave zoomfull
#.wave.tree zoomfull	# with some versions of ModelSim
