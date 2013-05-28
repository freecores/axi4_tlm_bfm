/*
	This file is part of the AXI4 Transactor and Bus Functional Model 
	(axi4_tlm_bfm) project:
		http://www.opencores.org/project,axi4_tlm_bfm

	Description
	Implementation of AXI4 Master BFM core according to AXI4 protocol 
	specification document.
	
	To Do: Implement AXI4-Lite and full AXI4 protocols.
	
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
library ieee; use ieee.std_logic_1164.all, ieee.numeric_std.all;
library tauhop; use tauhop.transactor.all, tauhop.axiTransactor.all;

--/* TODO remove once generic packages are supported. */
--library tauhop; use tauhop.tlm.all, tauhop.axiTLM.all;

entity axiBfmMaster is --generic(constant maxTransactions:positive);
	port(aclk,n_areset:in std_ulogic;
		/* User trigger. */
		trigger:in boolean;
		
		/* BFM signalling. */
		readRequest,writeRequest:in tBfmCtrl:=((others=>'X'),(others=>'X'),false);	-- this is tauhop.transactor.tBfmCtrl.
		readResponse,writeResponse:buffer tBfmCtrl;									-- use buffer until synthesis tools support reading from out ports.
		
		/* AXI Master interface */
		axiMaster_in:in tAxi4StreamTransactor_s2m;
		axiMaster_out:buffer tAxi4StreamTransactor_m2s;
		
--		/* AXI Slave interface */
--		axiSlave_in:in tAxi4Transactor_m2s;
--		axiSlave_out:buffer tAxi4Transactor_s2m;
		
		symbolsPerTransfer:in t_cnt;
		outstandingTransactions:out t_cnt;
		
		/* Debug ports. */
		dbg_cnt:out unsigned(9 downto 0);
		dbg_axiRxFsm:out axiBfmStatesRx:=idle;
		dbg_axiTxFsm:out axiBfmStatesTx:=idle
	);
end entity axiBfmMaster;

architecture rtl of axiBfmMaster is
	/* Finite-state Machines. */
	signal axiTxState,next_axiTxState:axiBfmStatesTx:=idle;
	
	/* General pipelines. */
	signal i_axiMaster_out:tAxi4StreamTransactor_m2s;
	
	/* BFM signalling. */
	signal i_readRequest:tBfmCtrl:=((others=>'0'),(others=>'0'),false);
	signal i_writeRequest:tBfmCtrl:=((others=>'0'),(others=>'0'),false);
	
	signal response,i_response:boolean;
	
begin
	/* Transaction counter. */
	process(n_areset,aclk) is begin
		if not n_areset then outstandingTransactions<=symbolsPerTransfer;
		elsif rising_edge(aclk) then
			if outstandingTransactions>0 then outstandingTransactions<=outstandingTransactions-1;
			else
				outstandingTransactions<=symbolsPerTransfer;
				report "No more pending transactions." severity note;
			end if;
		end if;
	end process;
	
	/* next-state logic for AXI4-Stream Master Tx BFM. */
	axi_bfmTx_ns: process(all) is begin
		axiTxState<=next_axiTxState;
		
		if not n_areset then axiTxState<=idle;
		elsif writeRequest.trigger xor i_writeRequest.trigger then axiTxState<=payload;
		end if;
		
		case next_axiTxState is
			when idle=>null;
			when payload=>
				if outstandingTransactions<1 then axiTxState<=idle; end if;
			when others=>axiTxState<=idle;
		end case;
	end process axi_bfmTx_ns;
	
	/* output logic for AXI4-Stream Master Tx BFM. */
	axi_bfmTx_op: process(all) is begin
		axiMaster_out<=i_axiMaster_out;
		
		case next_axiTxState is
			when payload=>
				axiMaster_out.tValid<=true;
				if axiMaster_in.tReady then
					axiMaster_out.tData<=writeRequest.message;		--TODO: writeRequest.message should change every aclk cycle.
				end if;
			when others=> axiMaster_out.tValid<=false; axiMaster_out.tData<=(others=>'Z');		--TODO: set 'Z' to '0' for synthesis.
		end case;
	end process axi_bfmTx_op;
	
	
	/* state registers and pipelines for AXI4-Stream Tx BFM. */
	process(n_areset,aclk) is begin
		if not n_areset then next_axiTxState<=idle;
		elsif rising_edge(aclk) then
			next_axiTxState<=axiTxState;
			i_axiMaster_out<=axiMaster_out;
			i_writeRequest<=writeRequest;
		end if;
	end process;
	
	dbg_axiTxFsm<=axiTxState;
end architecture rtl;
