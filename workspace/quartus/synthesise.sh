#!/bin/bash
quartus_sh --flow compile axi4-tlm
quartus_pgm -c 'USB-Blaster [1-1.6]' -m jtag -o 'p;./output_files/axi4-tlm.sof'
quartus_stpw ./waves.stp &
