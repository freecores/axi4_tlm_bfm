#!/bin/bash
#
#	Example bash script for Mentor Graphics QuestaSim/ModelSim simulation.
#	
# Author: Daniel C.K. Kho <daniel.kho@tauhop.com>
# Copyright© 2012-2013 Daniel C.K. Kho <daniel.kho@tauhop.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This notice and disclaimer must be retained as part of this text at all times.
#
#	@dependencies: 
#	@designer: Daniel C.K. Kho [daniel.kho@gmail.com] | [daniel.kho@tauhop.com]
#	@history: @see Mercurial log for full list of changes.
#	
#	@Description:
#

#read -p "press Enter to run full simulation now, or Ctrl-C to exit: ";
echo $(date "+[%Y-%m-%d %H:%M:%S]: Removing previously-generated files and folders...");
rm -rf modelsim.ini ./simulate.log ./work ./altera ./osvvm ./tauhop;

echo $(date "+[%Y-%m-%d %H:%M:%S]: Remove successful.");
echo $(date "+[%Y-%m-%d %H:%M:%S]: Compiling project...");
vlib work; vmap work work;
vlib altera; vmap altera altera;
vlib osvvm; vmap osvvm osvvm;
vlib tauhop; vmap tauhop tauhop;

vcom -2008 -work osvvm ../../rtl/packages/os-vvm/SortListPkg_int.vhd \
	../../rtl/packages/os-vvm/RandomBasePkg.vhd \
	../../rtl/packages/os-vvm/RandomPkg.vhd \
	../../rtl/packages/os-vvm/CoveragePkg.vhd;

vcom -2008 -work tauhop ../../rtl/packages/pkg-tlm.vhdl \
	../../rtl/packages/pkg-axi-tlm.vhdl \
	| tee -ai ./simulate.log;

vcom -2008 -work work ../../rtl/axi4-stream-bfm.vhdl \
	../../rtl/user.vhdl \
	| tee -ai ./simulate.log;

vsim -t ps -do ./waves.do -voptargs="+acc" "work.user(rtl)";
#vsim -t ps -do ./waves.do -voptargs="+acc" "work.system(structural)";
#vsim -t ps -do ./waves.do -voptargs="+acc" work.cfg_multiArch;

echo $(date "+[%Y-%m-%d %H:%M:%S]: simulation loaded.");
