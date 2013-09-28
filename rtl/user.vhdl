/*
	This file is part of the AXI4 Transactor and Bus Functional Model 
	(axi4_tlm_bfm) project:
		http://www.opencores.org/project,axi4_tlm_bfm

	Description
	Synthesisable use case for AXI4 on-chip messaging.
	
	To Do: 
	
	Author(s): 
	- Daniel C.K. Kho, daniel.kho@opencores.org | daniel.kho@tauhop.com
	
	Copyright (C) 2012-2013 Authors and OPENCORES.ORG
	
	This source file may be used and distributed without 
	restriction provided that this copyright statement is not 
	removed from the file and that any derivative work contains 
	the original copyright notice and the associated disclaimer.
	
	This source file is free software; you can redistribute it 
	and/or modify it under the terms of the GNU Lesser General 
	Public License as published by the Free Software Foundation; 
	either version 2.1 of the License, or (at your option) any 
	later version.
	
	This source is distributed in the hope that it will be 
	useful, but WITHOUT ANY WARRANTY; without even the implied 
	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
	PURPOSE. See the GNU Lesser General Public License for more 
	details.
	
	You should have received a copy of the GNU Lesser General 
	Public License along with this source; if not, download it 
	from http://www.opencores.org/lgpl.shtml.
*/
library ieee; use ieee.std_logic_1164.all, ieee.numeric_std.all; use ieee.math_real.all;
library tauhop; use tauhop.axiTransactor.all;

/* TODO remove once generic packages are supported. */
--library tauhop; use tauhop.tlm.all, tauhop.axiTLM.all;

/* synthesis translate_off */
library osvvm; use osvvm.RandomPkg.all; use osvvm.CoveragePkg.all;
/* synthesis translate_on */

entity user is port(
	/* Comment-out for simulation. */
--	clk,nReset:in std_ulogic;
	
	/* AXI Master interface */
--	axiMaster_in:in t_axi4StreamTransactor_s2m;
	axiMaster_out:buffer t_axi4StreamTransactor_m2s
	
	/* Debug ports. */
);
end entity user;

architecture rtl of user is
	/* Global counters. */
	constant maxSymbols:positive:=2048;		--maximum number of symbols allowed to be transmitted in a frame. Each symbol's width equals tData's width. 
	signal symbolsPerTransfer:i_transactor.t_cnt;
	signal outstandingTransactions:i_transactor.t_cnt;
	
	/* BFM signalling. */
	signal readRequest:i_transactor.t_bfm:=((others=>'0'),(others=>'0'),false);
	signal writeRequest:i_transactor.t_bfm:=((others=>'0'),(others=>'0'),false);
	signal readResponse:i_transactor.t_bfm;
	signal writeResponse:i_transactor.t_bfm;
	
	type txStates is (idle,transmitting);
	signal txFSM,i_txFSM:txStates;
	
	/* Tester signals. */
	/* synthesis translate_off */
	signal clk,nReset:std_ulogic:='0';
	/* synthesis translate_on */
	
	signal axiMaster_in:t_axi4StreamTransactor_s2m;
	signal irq_write:std_ulogic;		-- clock gating.
	
begin
	/* Bus functional models. */
	axiMaster: entity work.axiBfmMaster(rtl)
		port map(
			aclk=>irq_write, n_areset=>nReset,
			
			readRequest=>readRequest,	writeRequest=>writeRequest,
			readResponse=>readResponse,	writeResponse=>writeResponse,
			axiMaster_in=>axiMaster_in,
			axiMaster_out=>axiMaster_out,
			
			symbolsPerTransfer=>symbolsPerTransfer,
			outstandingTransactions=>outstandingTransactions
	);
	
	/* Interrupt-request generator. */
	irq_write<=clk when nReset else '0';
	
	/* Simulation Tester. */
	/* synthesis translate_off */
	clk<=not clk after 10 ps;
	process is begin
		nReset<='1'; wait for 1 ps;
		nReset<='0'; wait for 500 ps;
		nReset<='1';
		wait;
	end process;
	/* synthesis translate_on */
	
	/* Hardware tester. */
	
	
	/* Stimuli sequencer. TODO move to tester/stimuli.
		This emulates the AXI4-Stream Slave.
	*/
	/* Simulation-only stimuli sequencer. */
	/* synthesis translate_off */
	process is begin
		/* Fast read. */
		while not axiMaster_out.tLast loop
			/* Wait for tValid to assert. */
			while not axiMaster_out.tValid loop
				wait until falling_edge(clk);
			end loop;
			
			axiMaster_in.tReady<=true;
			
			wait until falling_edge(clk);
			axiMaster_in.tReady<=false;
		end loop;
		
		wait until falling_edge(clk);
		
		/* Normal read. */
		while not axiMaster_out.tLast loop
			/* Wait for tValid to assert. */
			while not axiMaster_out.tValid loop
				wait until falling_edge(clk);
			end loop;
			
			wait until falling_edge(clk);
			axiMaster_in.tReady<=true;
			
			wait until falling_edge(clk);
			axiMaster_in.tReady<=false;
		end loop;
		
		for i in 0 to 10 loop
			wait until falling_edge(clk);
		end loop;
		
		/* One-shot read. */
		axiMaster_in.tReady<=true;
		
		wait until falling_edge(clk);
		axiMaster_in.tReady<=false;
		
		wait;
	end process;
	/* synthesis translate_on */
	
	/* Synthesisable stimuli sequencer. */
	
	
	/* Data transmitter. */
	sequencer_ns: process(all) is begin
		txFSM<=i_txFSM;
		if not nReset then txFSM<=idle;
		else
			case i_txFSM is
				when idle=>
					if outstandingTransactions>0 then txFSM<=transmitting; end if;
				when transmitting=>
					if axiMaster_out.tLast then
						txFSM<=idle;
					end if;
				when others=> null;
			end case;
		end if;
	end process sequencer_ns;
	
	sequencer_op: process(nReset,irq_write) is
		/* Local procedures to map BFM signals with the package procedure. */
		procedure read(address:in i_transactor.t_addr) is begin
			i_transactor.read(readRequest,address);
		end procedure read;
		
		procedure write(data:in i_transactor.t_msg) is begin
			i_transactor.write(request=>writeRequest, address=>(others=>'-'), data=>data);
		end procedure write;
		
		variable isPktError:boolean;
		
		/* Tester variables. */
        /* Synthesis-only randomisation. */
		
		/* Simulation-only randomisation. */
		/* synthesis translate_off */
		variable rv0:RandomPType;
		/* synthesis translate_on */
		
	begin
		if not nReset then
			/*simulation only. */
			/* synthesis translate_off */
			rv0.InitSeed(rv0'instance_name);
			/* synthesis translate_on */
		elsif falling_edge(irq_write) then
			case txFSM is
				when transmitting=>
					if txFSM/=i_txFSM or writeResponse.trigger then
						/* synthesis translate_off */
						write(rv0.RandSigned(axiMaster_out.tData'length));
						/* synthesis translate_on */
					end if;
				when others=>null;
			end case;
		end if;
	end process sequencer_op;
	
	sequencer_regs: process(irq_write) is begin
		if falling_edge(irq_write) then
			i_txFSM<=txFSM;
		end if;
	end process sequencer_regs;
	
	/* Reset symbolsPerTransfer to new value (prepare for new transfer) after current transfer has been completed. */
	process(nReset,irq_write) is
		/* synthesis translate_off */
		variable rv0:RandomPType;
		/* synthesis translate_on */
	begin
		if not nReset then
			/* synthesis translate_off */
			rv0.InitSeed(rv0'instance_name);
			symbolsPerTransfer<=120x"0" & rv0.RandUnsigned(8);
			report "symbols per transfer = 0x" & ieee.numeric_std.to_hstring(rv0.RandUnsigned(axiMaster_out.tData'length));
			/* synthesis translate_on */
		elsif rising_edge(irq_write) then
			if axiMaster_out.tLast then
				/* synthesis translate_off */
				symbolsPerTransfer<=120x"0" & rv0.RandUnsigned(8);
				report "symbols per transfer = 0x" & ieee.numeric_std.to_hstring(rv0.RandUnsigned(axiMaster_out.tData'length));
				/* synthesis translate_on */
			end if;
		end if;
	end process;
end architecture rtl;
