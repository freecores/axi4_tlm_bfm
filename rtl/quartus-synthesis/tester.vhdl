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


entity tester is port(
	/* Comment-out for simulation. */
	clk,reset:in std_ulogic;
	
	/* AXI Master interface */
	axiMaster_in:buffer t_axi4StreamTransactor_s2m;
	axiMaster_out:in t_axi4StreamTransactor_m2s;
	
	/* BFM signalling. */
--	readRequest,writeRequest:t_bfm:=(address=>(others=>'X'),message=>(others=>'X'),trigger=>false);
--	readResponse,writeResponse:t_bfm;
	readRequest,writeRequest:buffer t_bfm;
	readResponse,writeResponse:in t_bfm;
	
	irq_write:buffer std_ulogic;		-- clock gating.
	
	symbolsPerTransfer:buffer t_cnt;
	outstandingTransactions:buffer t_cnt;
	
	/* Debug ports. */
--	dataIn:in t_msg;
	selTxn:in unsigned(3 downto 0)
);
end entity tester;

architecture rtl of tester is
--	signal reset:std_ulogic:='0';
	signal locked:std_ulogic;
	signal porCnt:unsigned(3 downto 0);
	signal trigger:boolean;
	
	/* Global counters. */
	constant maxSymbols:positive:=2048;		--maximum number of symbols allowed to be transmitted in a frame. Each symbol's width equals tData's width. 
--	signal symbolsPerTransfer:t_cnt;
--	signal outstandingTransactions:t_cnt;
	
--	/* BFM signalling. */
--	signal readRequest,writeRequest:t_bfm:=(address=>(others=>'X'),message=>(others=>'X'),trigger=>false);
--	signal readResponse,writeResponse:t_bfm;
	
	type txStates is (idle,transmitting);
	signal txFSM,i_txFSM:txStates;
	
	/* Tester signals. */
	/* synthesis translate_off */
	signal clk,nReset:std_ulogic:='0';
	attribute period:time; attribute period of clk:signal is 10 ps;
	/* synthesis translate_on */
	
	signal testerClk:std_ulogic;
	signal dbg_axiTxFSM:axiBfmStatesTx;
	signal anlysr_dataIn:std_logic_vector(127 downto 0);
	signal anlysr_trigger:std_ulogic;
	
--	signal axiMaster_in:t_axi4StreamTransactor_s2m;
--	signal irq_write:std_ulogic;		-- clock gating.
	
	signal prbs:t_msg;
	
begin
	/* PLL to generate tester's clock. */
    f100MHz: entity altera.pll(syn) port map(
        areset=>'0',    --not nReset,
        inclk0=>clk,
        c0=>testerClk,
        locked=>locked
    );
	
	/* Interrupt-request generator. */
	trigger<=txFSM/=i_txFSM or writeResponse.trigger;
	irq_write<=clk when not reset else '0';
	
	/* SignalTap II embedded logic analyser. Included as part of BiST architecture. */
	--anlysr_trigger<='1' when writeRequest.trigger else '0';
	anlysr_trigger<='1' when reset else '0';
	
	/* Disable this for synthesis as this is not currently synthesisable.
		Pull the framerFSM statemachine signal from lower down the hierarchy to this level instead.
	*/
	/* synthesis translate_off */
	--framerFSM<=to_unsigned(<<signal framers_txs(0).i_framer.framerFSM: framerFsmStates>>,framerFSM'length);
	/* synthesis translate_on */
	
	anlysr_dataIn(7 downto 0)<=std_logic_vector(symbolsPerTransfer(7 downto 0));
	anlysr_dataIn(15 downto 8)<=std_logic_vector(outstandingTransactions(7 downto 0));
	--anlysr_dataIn(2 downto 0) <= <<signal axiMaster.axiTxState:axiBfmStatesTx>>;
	anlysr_dataIn(17 downto 16)<=to_std_logic_vector(dbg_axiTxFSM);
	anlysr_dataIn(18)<='1' when clk else '0';
	anlysr_dataIn(19)<='1' when reset else '0';
	anlysr_dataIn(20)<='1' when irq_write else '0';
	anlysr_dataIn(21)<='1' when axiMaster_in.tReady else '0';
	anlysr_dataIn(22)<='1' when axiMaster_out.tValid else '0';
	anlysr_dataIn(54 downto 23)<=std_logic_vector(axiMaster_out.tData);
	anlysr_dataIn(86 downto 55)<=std_logic_vector(prbs);
	anlysr_dataIn(90 downto 87)<=std_logic_vector(axiMaster_out.tStrb);
	anlysr_dataIn(94 downto 91)<=std_logic_vector(axiMaster_out.tKeep);
	anlysr_dataIn(95)<='1' when axiMaster_out.tLast else '0';
	anlysr_dataIn(96)<='1' when writeRequest.trigger else '0';
	anlysr_dataIn(97)<='1' when writeResponse.trigger else '0';
	--anlysr_dataIn(99 downto 98)<=to_std_logic_vector(txFSM);
	anlysr_dataIn(101 downto 98)<=std_logic_vector(porCnt);
--	anlysr_dataIn(102)<='1' when locked else '0';
--	anlysr_dataIn(102)<=locked;
	
	anlysr_dataIn(anlysr_dataIn'high downto 102)<=(others=>'0');
	
	
	/* Simulate only if you have compiled Altera's simulation libraries. */
	i_bist_logicAnalyser: entity altera.stp(syn) port map(
		acq_clk=>testerClk,
		acq_data_in=>anlysr_dataIn,
		acq_trigger_in=>"1",
		trigger_in=>anlysr_trigger
	);
	
	
	
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
		
		wait until falling_edge(clk);
		report "Performing normal read..." severity note;
		
		/* Normal read. */
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
		
		report "Completed normal read." severity note;
		
		for i in 0 to 10 loop
			wait until falling_edge(clk);
		end loop;
		
		/* One-shot read. */
		axiMaster_in.tReady<=true;
		
		wait until falling_edge(clk);
		axiMaster_in.tReady<=false;
		
		report "Completed one-shot read." severity note;
		
		wait;
	end process;
	/* synthesis translate_on */
	
	/* Synthesisable stimuli sequencer. */
	process(clk) is begin
		if falling_edge(clk) then
			axiMaster_in.tReady<=false;
			--if axiMaster_out.tValid and not axiMaster_out.tLast then
			if not axiMaster_in.tReady and axiMaster_out.tValid and not axiMaster_out.tLast then
				axiMaster_in.tReady<=true;
			end if;
		end if;
	end process;
	
	
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
		procedure read(address:in t_addr) is begin
			read(readRequest,address);
		end procedure read;
		
		procedure write(data:in t_msg) is begin
			write(request=>writeRequest, address=>(others=>'-'), data=>data);
		end procedure write;
		
		variable isPktError:boolean;
		
		/* Tester variables. */
		/* Synthesis-only randomisation. */
		
		/* Simulation-only randomisation. */
		/* synthesis translate_off */
		variable rv0:RandomPType;
		/* synthesis translate_on */
		
--		variable trigger:boolean;
	begin
--		if reset then
			/* simulation only. */
			/* synthesis translate_off */
--			rv0.InitSeed(rv0'instance_name);
			/* synthesis translate_on */
		if falling_edge(irq_write) then
			case txFSM is
				when transmitting=>
					if trigger then
						/* synthesis translate_off */
						write(rv0.RandSigned(axiMaster_out.tData'length));
						/* synthesis translate_on */
						
						--write(prbs);
						
						case selTxn is
							when x"1"=> write(32x"12ab34cd");
							when x"2"=> write(32x"12345678");
							when x"3"=> write(32x"87654321");
							when x"4"=> write(32x"abcd1234");
							when others=> write(prbs);
						end case;
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
		/* TODO close timing for asynchronous reset. */
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
			
			symbolsPerTransfer<=128x"fc";
		elsif rising_edge(irq_write) then
			if axiMaster_out.tLast then
				/* synthesis only. */
				/* Testcase 1: number of symbols per transfer becomes 0 after first stream transfer. */
				--symbolsPerTransfer<=(others=>'0');
				
				/* Testcase 2: number of symbols per transfer is randomised. */
				--uniform(seed0,seed1,rand0);
				--symbolsPerTransfer<=120x"0" & to_unsigned(integer(rand0 * 2.0**8),8);	--symbolsPerTransfer'length
				--report "symbols per transfer = " & ieee.numeric_std.to_hstring(to_unsigned(integer(rand0 * 2.0**8),8));	--axiMaster_out.tData'length));
				
				
				/* synthesis translate_off */
				symbolsPerTransfer<=120x"0" & rv0.RandUnsigned(8);
				report "symbols per transfer = 0x" & ieee.numeric_std.to_hstring(rv0.RandUnsigned(axiMaster_out.tData'length)) severity note;
				/* synthesis translate_on */
				
				symbolsPerTransfer<=128x"0f";		--128x"ffffffff_ffffffff_ffffffff_ffffffff";
			end if;
		end if;
	end process;

--    outstandingTransactions<=128x"fc";      --symbolsPerTransfer;
end architecture rtl;
