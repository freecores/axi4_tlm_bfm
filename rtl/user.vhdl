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
library tauhop; use tauhop.transactor.all, tauhop.axiTransactor.all;
--/* synthesis translate_off */
--library osvvm; use osvvm.RandomPkg.all; use osvvm.CoveragePkg.all;
--/* synthesis translate_on */

entity user is port(
	/* Comment-out for simulation. */
--	clk,reset:in std_ulogic;
	
	/* AXI Master interface */
--	axiMaster_in:in tAxi4StreamTransactor_s2m;
	axiMaster_out:buffer tAxi4StreamTransactor_m2s
	
	/* Debug ports. */
);
end entity user;

architecture rtl of user is
	/* Global counters. */
	constant maxSymbols:positive:=2048;		--maximum number of symbols allowed to be transmitted in a frame. Each symbol's width equals tData's width. 
	signal symbolsPerTransfer:t_cnt;
	signal outstandingTransactions:t_cnt;
	
	/* BFM signalling. */
	signal readRequest,next_readRequest:tBfmCtrl:=((others=>'0'),(others=>'0'),false);
	signal writeRequest,next_writeRequest:tBfmCtrl:=((others=>'0'),(others=>'0'),false);
	signal readResponse,next_readResponse:tBfmCtrl;
	signal writeResponse,next_writeResponse:tBfmCtrl;
	
	
	/* Tester signals. */
	/* synthesis translate_off */
	signal clk,reset:std_ulogic:='0';
	signal axiMaster_in:tAxi4StreamTransactor_s2m;
	/* synthesis translate_on */
	
	signal irq_write:std_ulogic;		-- clock gating.
	
begin
	/* pipelines. */
	process(reset,clk) is begin
		if rising_edge(clk) then
			next_readRequest<=readRequest;
			next_writeRequest<=writeRequest;
			next_readResponse<=readResponse;
			next_writeResponse<=writeResponse;
		end if;
	end process;
	
	
	/* Bus functional models. */
	axiMaster: entity work.axiBfmMaster(rtl)
--		generic map(maxTransactions=>maxSymbols)
		port map(
			aclk=>irq_write, n_areset=>not reset,
			trigger=>irq_write='1',
			
			readRequest=>readRequest,	writeRequest=>writeRequest,
			readResponse=>readResponse,	writeResponse=>writeResponse,
			axiMaster_in=>axiMaster_in,
			axiMaster_out=>axiMaster_out,
			
			symbolsPerTransfer=>symbolsPerTransfer,
			outstandingTransactions=>outstandingTransactions,
			
			dbg_cnt=>open,
			dbg_axiRxFsm=>open,
			dbg_axiTxFsm=>open
	);
	
	/* Simulation Tester. */
	/* synthesis translate_off */
	clk<=not clk after 10 ps;
	process is begin
		reset<='0'; wait for 1 ps;
		reset<='1'; wait for 500 ps;
		reset<='0';
		wait;
	end process;
	
	axiMaster_in.tReady<=true when axiMaster_out.tValid and falling_edge(clk);
	/* synthesis translate_on */
	
	/* Hardware tester. */
	
	/* Interrupt-request generator. */
	irq_write<=clk when not reset;
	
	/* Stimuli sequencer. */
	sequencer: process(reset,irq_write) is
		/* Local procedures to map BFM signals with the package procedure. */
		procedure read(address:in unsigned(31 downto 0)) is begin
			read(readRequest,address);
		end procedure read;
		
		procedure write(
			address:in t_addr;
			data:in t_msg
		) is begin
			write(writeRequest,address,data);
		end procedure write;
		
		procedure writeStream(
			data:in t_msg
		) is begin
			writeStream(writeRequest,data);
		end procedure writeStream;
		
		variable isPktError:boolean;
		
		/* Simulation-only randomisation. */
		variable seed0,seed1:positive:=1;
		variable rand0,rand1:real;
		
	begin
		if reset then
			seed0:=1; seed1:=1;
			
			uniform(seed0,seed1,rand0);
			symbolsPerTransfer<=120x"0" & to_unsigned(integer(rand0*4096.0),8);
		elsif falling_edge(irq_write) then
			if outstandingTransactions>0 then
				uniform(seed0,seed1,rand0);
				writeStream(to_unsigned(integer(rand0*4096.0),64));
				
			else
				/* Testcase 1: number of symbols per transfer becomes 0 after first stream transfer. */
				--symbolsPerTransfer<=(others=>'0');
				
				/* Testcase 2: number of symbols per transfer is randomised. */
				uniform(seed0,seed1,rand0);
				symbolsPerTransfer<=120x"0" & to_unsigned(integer(rand0*4096.0),8);	--symbolsPerTransfer'length
				report "symbols per transfer = " & ieee.numeric_std.to_hstring(to_unsigned(integer(rand0*4096.0),8));	--axiMaster_out.tData'length));
			end if;
		end if;
	end process sequencer;
end architecture rtl;
