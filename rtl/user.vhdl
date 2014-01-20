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
	signal reset:std_ulogic:='0';
	signal porCnt:unsigned(3 downto 0);
	signal trigger:boolean;
	
	/* Global counters. */
	constant maxSymbols:positive:=2048;		--maximum number of symbols allowed to be transmitted in a frame. Each symbol's width equals tData's width. 
	signal symbolsPerTransfer:i_transactor.t_cnt;
	signal outstandingTransactions:i_transactor.t_cnt;
	
	/* BFM signalling. */
	signal readRequest,writeRequest:i_transactor.t_bfm:=(address=>(others=>'X'),message=>(others=>'X'),trigger=>false);
	signal readResponse,writeResponse:i_transactor.t_bfm;
	
	type txStates is (idle,transmitting);
	signal txFSM,i_txFSM:txStates;
	
	/* Tester signals. */
	/* synthesis translate_off */
	signal clk,nReset:std_ulogic:='0';
	attribute period:time; attribute period of clk:signal is 10 ps;
	/* synthesis translate_on */
	
	signal axiMaster_in:t_axi4StreamTransactor_s2m;
	signal irq_write:std_ulogic;		-- clock gating.
	
	signal prbs:i_transactor.t_msg;
	
begin
	/* Bus functional models. */
	axiMaster: entity tauhop.axiBfmMaster(rtl)
	--axiMaster: entity work.axiBfmMaster(simulation)
		port map(
			aclk=>irq_write, n_areset=>not reset,
			
			readRequest=>readRequest,	writeRequest=>writeRequest,
			readResponse=>readResponse,	writeResponse=>writeResponse,
			axiMaster_in=>axiMaster_in,
			axiMaster_out=>axiMaster_out,
			
			symbolsPerTransfer=>symbolsPerTransfer,
			outstandingTransactions=>outstandingTransactions
	);
	
	/* Interrupt-request generator. */
	trigger<=txFSM/=i_txFSM or writeResponse.trigger;
	irq_write<=clk when not reset else '0';
	
	/* Simulation Tester. */
	/* synthesis translate_off */
	clk<=not clk after clk'period/2;
	process is begin
		nReset<='1'; wait for 1 ps;
		nReset<='0'; wait for 500 ps;
		nReset<='1';
		wait;
	end process;
	/* synthesis translate_on */
	
	
	/* Hardware tester. */
	/* Power-on Reset circuitry. */
	por: process(nReset,clk) is begin
		if not nReset then reset<='1'; porCnt<=(others=>'1');
		elsif rising_edge(clk) then
			reset<='0';
			
			if porCnt>0 then reset<='1'; porCnt<=porCnt-1; end if;
		end if;
	end process por;
	
/*
	process is
		alias trigger is <<signal axiMaster.trigger:boolean>>;
		alias axiTxState is <<signal axiMaster.next_axiTxState:axiBfmStatesTx>>;
	begin
		-- Remove this assertion once request queue has been implemented.
		if trigger then
			assert axiTxState=idle or axiTxState=payload report "[Error]: Trigger occurs when FSM is not in IDLE or PAYLOAD state." severity error;
		end if;
		wait for clk'period/10;
	end process;
*/	
	
	/* Stimuli sequencer. TODO move to tester/stimuli.
		This emulates the AXI4-Stream Slave.
	*/
	/* Simulation-only stimuli sequencer. */
	/* synthesis translate_off */
	process is begin
		report "Performing fast read..." severity note;
		
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
		
		report "Completed fast read..." severity note;
		
		
		wait until falling_edge(clk);
		report "Performing normal read..." severity note;
		
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
			
			wait until falling_edge(clk);
		end loop;
		
		report "Completed normal read." severity note;
		
		
		wait until falling_edge(clk);
		report "Performing slow read..." severity note;
		
		/* Slow read. */
		while not axiMaster_out.tLast loop
			/* Wait for tValid to assert. */
			while not axiMaster_out.tValid loop
				wait until falling_edge(clk);
			end loop;
			
			wait until falling_edge(clk);
			wait until falling_edge(clk);
			axiMaster_in.tReady<=true;
			
			wait until falling_edge(clk);
			axiMaster_in.tReady<=false;
			
			wait until falling_edge(clk);
		end loop;
		
		report "Completed slow read." severity note;
		
		
		for i in 0 to 10 loop
			wait until falling_edge(clk);
		end loop;
		report "Performing one-shot read..." severity note;
		
		/* One-shot read. */
		axiMaster_in.tReady<=true;
		
		wait until falling_edge(clk);
		axiMaster_in.tReady<=false;
		
		report "Completed one-shot read." severity note;
		
		wait;
	end process;
	/* synthesis translate_on */
	
	/* Synthesisable stimuli sequencer. */
	
	
	/* Data transmitter. */
	i_prbs: entity tauhop.prbs31(rtl)
		generic map(
			isParallelLoad=>true,
			tapVector=>(
				/* Example polynomial from Wikipedia:
					http://en.wikipedia.org/wiki/Computation_of_cyclic_redundancy_checks
				*/
				0|3|31=>true, 1|2|30 downto 4=>false
			)
		)
		port map(
			/* Comment-out for simulation. */
			clk=>irq_write, reset=>reset,
			en=>trigger,
			seed=>32x"ace1",        --9x"57",
			prbs=>prbs
		);
	
	sequencer_ns: process(all) is begin
		txFSM<=i_txFSM;
		if reset then txFSM<=idle;
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
	
	sequencer_op: process(reset,irq_write) is
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
--		if reset then
			/* simulation only. */
			/* synthesis translate_off */
--			rv0.InitSeed(rv0'instance_name);
			/* synthesis translate_on */
--		elsif falling_edge(irq_write) then
		if falling_edge(irq_write) then
			case txFSM is
				when transmitting=>
					if trigger then
						/* synthesis translate_off */
--						write(rv0.RandSigned(axiMaster_out.tData'length));
						/* synthesis translate_on */
						write(prbs);
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
	
	/* Transaction counter. */
	process(reset,symbolsPerTransfer,irq_write) is begin
		if reset then outstandingTransactions<=symbolsPerTransfer;
		elsif rising_edge(irq_write) then
			if not axiMaster_out.tLast then
				if outstandingTransactions<1 then
					outstandingTransactions<=symbolsPerTransfer;
					report "No more pending transactions." severity note;
				elsif axiMaster_in.tReady then outstandingTransactions<=outstandingTransactions-1;
				end if;
			end if;
			
			/* Use synchronous reset for outstandingTransactions to meet timing because it is a huge register set. */
			if reset then outstandingTransactions<=symbolsPerTransfer; end if;
		end if;
	end process;
	
	/* Reset symbolsPerTransfer to new value (prepare for new transfer) after current transfer has been completed. */
	process(reset,irq_write) is
		/* synthesis translate_off */
		variable rv0:RandomPType;
		/* synthesis translate_on */
	begin
		if reset then
			/* synthesis translate_off */
			rv0.InitSeed(rv0'instance_name);
			symbolsPerTransfer<=120x"0" & rv0.RandUnsigned(8);
			report "symbols per transfer = 0x" & ieee.numeric_std.to_hstring(rv0.RandUnsigned(axiMaster_out.tData'length)) severity note;
			/* synthesis translate_on */
		elsif rising_edge(irq_write) then
			if axiMaster_out.tLast then
				/* synthesis translate_off */
				symbolsPerTransfer<=120x"0" & rv0.RandUnsigned(8);
				report "symbols per transfer = 0x" & ieee.numeric_std.to_hstring(rv0.RandUnsigned(axiMaster_out.tData'length)) severity note;
				/* synthesis translate_on */
			end if;
		end if;
	end process;
end architecture rtl;
