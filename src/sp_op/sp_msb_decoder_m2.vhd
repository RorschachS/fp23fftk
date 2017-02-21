-------------------------------------------------------------------------------
--
-- Title       : sp_msb_decoder_m2
-- Design      : fp24fftk
-- Author      : Kapitanov
-- Company     : 
--
-------------------------------------------------------------------------------
--
-- Description : version 2.0
-- 				 RLOC, BEL attributes included, latency = 4 clocks
--				 Decoder includes 2 sp_msb_decoder_m1 modules and some logic elements				
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	The MIT License (MIT)
--	Copyright (c) 2016 Kapitanov Alexander 													 
--		                                          				 
-- Permission is hereby granted, free of charge, to any person obtaining a copy 
-- of this software and associated documentation files (the "Software"), 
-- to deal in the Software without restriction, including without limitation 
-- the rights to use, copy, modify, merge, publish, distribute, sublicense, 
-- and/or sell copies of the Software, and to permit persons to whom the 
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in 
-- all copies or substantial portions of the Software.
--
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
-- IN THE SOFTWARE.
-- 	                                                 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

entity sp_msb_decoder_m2 is
	port(
		din 	: in std_logic_vector(31 downto 0);
		din_en  : in std_logic;
		clk 	: in std_logic;
		reset 	: in std_logic;
		dout 	: out std_logic_vector(4 downto 0)
	);
end sp_msb_decoder_m2;

architecture sp_msb_decoder_m2 of sp_msb_decoder_m2 is

component sp_msb_decoder_m1 is
	port(
		din 	: in std_logic_vector(15 downto 0);
		din_en  : in std_logic;
		clk 	: in std_logic;
		reset 	: in std_logic;
		dout 	: out std_logic_vector(3 downto 0)
	);
end component;

signal msb_lo				: std_logic_vector(3 downto 0);
signal msb_hi				: std_logic_vector(3 downto 0);	 
signal hi_or				: std_logic;
signal din_or				: std_logic;
signal hi_orz				: std_logic;
signal dinz					: std_logic;
signal dinzz				: std_logic;
signal dinzzz				: std_logic;

attribute BEL				: string;
attribute RLOC				: string;
 
attribute BEL of lut_or		: label is "A6LUT";
attribute BEL of fdre_or	: label is "FFA";
attribute RLOC of lut_or	: label is "X0Y0"; 
attribute RLOC of fdre_or	: label is "X0Y0";

attribute BEL of pr_z		: label is "FFB";
attribute RLOC of pr_z		: label is "X0Y0";
attribute BEL of pr_zz		: label is "FFC";
attribute RLOC of pr_zz		: label is "X0Y0";
attribute BEL of pr_zzz		: label is "FFD";
attribute RLOC of pr_zzz	: label is "X0Y0";
begin

pr_z: 	dinz	<= din(16) when rising_edge(clk);
pr_zz: 	dinzz	<= dinz when rising_edge(clk);
pr_zzz: dinzzz	<= dinzz when rising_edge(clk);

msb_low: sp_msb_decoder_m1 
port map(
	din 	=> din(15 downto 0), 	
	din_en  => din_en, 					
	clk 	=> clk, 					
	reset 	=> reset, 					
	dout 	=> msb_lo 			 						
); 

msb_high: sp_msb_decoder_m1 
port map(
	din 	=> din(31 downto 16), 	
	din_en  => din_en, 					
	clk 	=> clk, 					
	reset 	=> reset, 					
	dout 	=> msb_hi 			 						
);

lut_or: LUT5 
generic map(INIT => X"FFFFFFFE")
port map(
	I0 => msb_hi(0), 
	I1 => msb_hi(1), 
	I2 => msb_hi(2), 
	I3 => msb_hi(3),
	I4 => dinzzz,
	O  => hi_or 
	);

fdre_or: FDRE 
generic map(INIT => '0')
port map
(
	Q 	=> hi_orz,
	C   => clk, 
	CE  => din_en,
	R 	=> reset,
	D   => hi_or 
);

dout(4) <= hi_orz after 1 ns;
pr_mux: process(reset, clk) is
begin 
	if reset = '1' then
		dout(3 downto 0) <= x"0";
	elsif rising_edge(clk) then
		if hi_or = '0' then
			dout(3 downto 0) <= msb_lo after 1 ns;
		else 
			dout(3 downto 0) <= msb_hi  after 1 ns;
		end if;
	end if;
end process;

end sp_msb_decoder_m2;
