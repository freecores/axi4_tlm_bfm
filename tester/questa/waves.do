configure wave -signalnamewidth 1

add wave -divider "DUV"
add wave -position end -decimal sim:/user/symbolsPerTransfer
add wave -position end -decimal sim:/user/axiMaster/outstandingTransactions
add wave -position end  sim:/user/axiMaster/axiTxState
add wave -position end  sim:/user/axiMaster/next_axiTxState

add wave -divider "Tester"
add wave -position end  sim:/user/clk
add wave -position end  sim:/user/reset
add wave -position end  sim:/user/irq_write
add wave -position end -expand -hexadecimal sim:/user/axiMaster_in
add wave -position end -expand -hexadecimal sim:/user/axiMaster_out
add wave -position end -decimal sim:/user/readRequest
add wave -position end -expand -hexadecimal sim:/user/writeRequest
add wave -position end -decimal sim:/user/readResponse
add wave -position end -expand -hexadecimal sim:/user/axiMaster/i_writeResponse
add wave -position end -expand -hexadecimal sim:/user/writeResponse
add wave -position end sim:/user/txFSM
add wave -position end -unsigned -format analog-step -height 80 -scale 0.4e-17 sim:/user/axiMaster_out.tData

run 80 ns;

wave zoomfull
#.wave.tree zoomfull	# with some versions of ModelSim
