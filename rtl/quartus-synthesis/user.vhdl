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
--library tauhop; use tauhop.transactor.all, tauhop.axiTransactor.all;		--TODO just use axiTransactor here as transactor should already be wrapped up.

/* TODO remove once generic packages are supported. */
library tauhop; use tauhop.tlm.all, tauhop.axiTLM.all;

/* synthesis translate_off */
library osvvm; use osvvm.RandomPkg.all; use osvvm.CoveragePkg.all;
/* synthesis translate_on */

library altera; use altera.stp;


entity user is port(
	/* Comment-out for simulation. */
	clk,nReset:in std_ulogic;
	
	/* AXI Master interface */
--	axiMaster_in:in t_axi4StreamTransactor_s2m;
	axiMaster_out:buffer t_axi4StreamTransactor_m2s
	
	/* Debug ports. */
);
end entity user;

architecture rtl of user is
	/* Global counters. */
	constant maxSymbols:positive:=2048;		--maximum number of symbols allowed to be transmitted in a frame. Each symbol's width equals tData's width. 
	signal symbolsPerTransfer:t_cnt;
	signal outstandingTransactions:t_cnt;
	
	/* BFM signalling. */
	signal readRequest,next_readRequest:t_bfm:=((others=>'0'),(others=>'0'),false);
	signal writeRequest,next_writeRequest:t_bfm:=((others=>'0'),(others=>'0'),false);
	signal readResponse,next_readResponse:t_bfm;
	signal writeResponse,next_writeResponse:t_bfm;
	
	
	/* Tester signals. */
	/* synthesis translate_off */
	signal clk,nReset:std_ulogic:='0';
	/* synthesis translate_on */
	signal trigger:boolean;
	signal anlysr_dataIn:std_logic_vector(127 downto 0);
	signal anlysr_trigger:std_ulogic;
	
	/* Signal preservations for SignalTap II probing. */
	attribute keep:boolean;
	attribute keep of trigger:signal is true;
	
	signal axiMaster_in:t_axi4StreamTransactor_s2m;
	signal irq_write:std_ulogic;		-- clock gating.
	
begin
	/* pipelines. */
	process(clk) is begin
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
			aclk=>irq_write, n_areset=>nReset,
			trigger=>irq_write='1',
			
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
	/* directly instantiated if configurations is not used.
		component-instantiated if configurations are used.
	*/
--	i_bist: entity work.framer_bist(tc1)
	/*i_bist: entity work.framer_bist(tc2_randomised)
		generic map(interPktGap=>3, pktSize=>pktSize)
		port map(nReset=>nReset, clk=>clk,
			trigger=>trigger,
			txDataIn=>txDataIn,
			txOut=>data(0),
			dataFault=>dataFault, crcFault=>crcFault
	);
	*/
	
	/* SignalTap II embedded logic analyser. Included as part of BiST architecture. */
	--trigger<=clk='1';
	--anlysr_trigger<='1' when trigger else '0';
	anlysr_trigger<='1' when writeRequest.trigger else '0';
	
	/* Disable this for synthesis as this is not currently synthesisable.
		Pull the framerFSM statemachine signal from lower down the hierarchy to this level instead.
	*/
	/* synthesis translate_off */
	--framerFSM<=to_unsigned(<<signal framers_txs(0).i_framer.framerFSM: framerFsmStates>>,framerFSM'length);
	/* synthesis translate_on */
	
	anlysr_dataIn(0)<='1' when nReset else '0';
	anlysr_dataIn(1)<='1' when irq_write else '0';
	anlysr_dataIn(2)<='1' when axiMaster_in.tReady else '0';
	anlysr_dataIn(3)<='1' when axiMaster_out.tValid else '0';
	anlysr_dataIn(67 downto 4)<=std_logic_vector(axiMaster_out.tData);
	anlysr_dataIn(71 downto 68)<=std_logic_vector(axiMaster_out.tStrb);
	anlysr_dataIn(75 downto 72)<=std_logic_vector(axiMaster_out.tKeep);
	anlysr_dataIn(76)<='1' when axiMaster_out.tLast else '0';
	--anlysr_dataIn(2)<='1' when axiMaster_out.tValid else '0';
	anlysr_dataIn(77)<='1' when writeRequest.trigger else '0';
	
	anlysr_dataIn(anlysr_dataIn'high downto 78)<=(others=>'0');
	
	
	/* Simulate only if you have compiled Altera's simulation libraries. */
	i_bistFramer_stp_analyser: entity altera.stp(syn) port map(
		acq_clk=>clk,
		acq_data_in=>anlysr_dataIn,
		acq_trigger_in=>"1",
		trigger_in=>anlysr_trigger
	);
	
	
	
	/* Stimuli sequencer. */
	axiMaster_in.tReady<=true when axiMaster_out.tValid and falling_edge(clk);
	
	sequencer: process(nReset,irq_write) is
		/* Local procedures to map BFM signals with the package procedure. */
		procedure read(address:in t_addr) is begin
			read(readRequest,address);
		end procedure read;
		
		procedure write(data:in t_msg) is begin
			write(request=>writeRequest, address=>(others=>'-'), data=>data);
		end procedure write;
		
		variable isPktError:boolean;
		
		/* Tester variables. */
		/* Synthesis-only randomisation. */
		variable seed0,seed1:positive:=1;
		--variable rand0:real;
		variable rand0:signed(63 downto 0);
		/* Simulation-only randomisation. */
		/* synthesis translate_off */
		variable rv0,rv1:RandomPType;
		/* synthesis translate_on */
		
	begin
		if not nReset then
			/* synthesis only. */
			seed0:=1; seed1:=1;
			--uniform(seed0,seed1,rand0);
			rand0:=(others=>'0');
			
			--symbolsPerTransfer<=120x"0" & to_unsigned(integer(rand0 * 2.0**8),8);
			symbolsPerTransfer<=128x"8";
			
			
			/* simulation only. */
			/* synthesis translate_off */
			rv0.InitSeed(rv0'instance_name);
			rv1.InitSeed(rv1'instance_name);
			symbolsPerTransfer<=120x"0" & rv0.RandUnsigned(8);
			/* synthesis translate_on */
		elsif falling_edge(irq_write) then
			--write(64x"abcd1234");
			if outstandingTransactions>0 then
				/* synthesis only. */
				--uniform(seed0,seed1,rand0);
				--write(to_signed(integer(rand0 * 2.0**31),64));
				write(rand0);
				rand0:=rand0+1;
				
				/* simulation only. */
				/* synthesis translate_off */
				write(rv1.RandUnsigned(axiMaster_out.tData'length));
				/* synthesis translate_on */
			else
				/* synthesis only. */
				/* Testcase 1: number of symbols per transfer becomes 0 after first stream transfer. */
				--symbolsPerTransfer<=(others=>'0');
				
				/* Testcase 2: number of symbols per transfer is randomised. */
				--uniform(seed0,seed1,rand0);
				--symbolsPerTransfer<=120x"0" & to_unsigned(integer(rand0 * 2.0**8),8);	--symbolsPerTransfer'length
				--report "symbols per transfer = " & ieee.numeric_std.to_hstring(to_unsigned(integer(rand0 * 2.0**8),8));	--axiMaster_out.tData'length));
				symbolsPerTransfer<=128x"8";

				
				/* Truncate symbolsPerTransfer to 8 bits, so that it uses a "small" value for simulation. */
				/* simulation only. */
				/* synthesis translate_off */
				symbolsPerTransfer<=120x"0" & rv0.RandSigned(64);
				report "symbols per transfer = 0x" & ieee.numeric_std.to_hstring(rv0.RandUnsigned(axiMaster_out.tData'length));
				/* synthesis translate_on */
			end if;
		end if;
	end process sequencer;
end architecture rtl;
