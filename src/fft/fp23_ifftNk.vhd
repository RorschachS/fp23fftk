-------------------------------------------------------------------------------
--
-- Title       : fp23_ifftNk
-- Design      : IFFT
-- Author      : Kapitanov
-- Company     :
--
-------------------------------------------------------------------------------
--
-- Description : Floating-poinr Inverse Fast Fourier Transform: N = 8 to 512K
-- 					(You must use 2D-FFT for N > 512K!)
--
--    Input data: IN0 and IN1 where
--      IN0 - Even part of data
--      IN1 - Odd part of data flow
--    
--    Output data: OUT0 and OUT1 where
--      OUT0 - 1st half part of data
--      OUT1 - 2nd half part of data flow (length = NFFT)
--		
--		Clock enable (Input data valid) must be strobe N = 2^(NFFT) cycles
---     w/o interruption!!!
--
--      Example: 
--        Input data:   ________________________
--        DI_EN     ___/                        \____
--        DI_AA:        /0\/1\/2\/3\/4\/5\/6\/7\
--        DI_BB:        \8/\9/\A/\B/\C/\D/\E/\F/
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

use work.fp_m1_pkg.all;

entity fp23_ifftNk is
	generic(
		NFFT			: integer:=10;			--! Number of FFT stages   
		XSERIES			: string:="7SERIES";	--! FPGA family: for 6/7 series: "7SERIES"; for ULTRASCALE: "ULTRA";
		USE_DSP			: boolean:=false; 		--! use DSP48 for calculation PI * CNT
		USE_SCALE		: boolean:=false; 		--! use full scale rambs for twiddle factor
		USE_CONJ		: boolean:=false		--! Use conjugation for the butterfly
		--USE_FLY			: boolean:=true			--! Use butterfly
	);		
	port(
		reset  			: in  std_logic;		--! Global reset 
		clk 			: in  std_logic;		--! System clock 
	
		data_in0		: in fp23_complex;		--! Input data Even
		data_in1		: in fp23_complex;		--! Input data Odd
		data_en			: in std_logic;			--! Input valid data
		
		use_fly			: in std_logic;			--! '1' - use BFLY, '0' -don't use
	
		dout0 			: out fp23_complex;		--! Output data Even
		dout1 			: out fp23_complex;		--! Output data Odd
		dout_val		: out std_logic			--! Output valid data
	);
end fp23_ifftNk;

architecture fp23_ifftNk of fp23_ifftNk is

constant Nwidth	: integer:=(data_in0.re.exp'length+data_in0.re.man'length+1);
constant Nman	: integer:=data_in0.re.man'length;

signal rstp				: std_logic;

type complex_fp23xN 	is array (NFFT-1 downto 0) of fp23_complex;
--type complex_16xfp23xN  is array (15 downto 0) of complex_fp23xN;
signal ia 				: complex_fp23xN;
signal ib 				: complex_fp23xN; 
signal iax 				: complex_fp23xN;
signal ibx 				: complex_fp23xN; 

signal oa 				: complex_fp23xN;
signal ob 				: complex_fp23xN; 
signal oa1 				: complex_fp23xN;
signal ob1 				: complex_fp23xN; 
signal oa2 				: complex_fp23xN;
signal ob2 				: complex_fp23xN;
 
signal ww 				: complex_fp23xN; 

signal bfly_en			: std_logic_vector(NFFT-1 downto 0); 
signal bfly_enx			: std_logic_vector(NFFT-1 downto 0);
signal bfly_vl			: std_logic_vector(NFFT-1 downto 0);
signal bfly_vl1			: std_logic_vector(NFFT-1 downto 0);
signal bfly_vl2			: std_logic_vector(NFFT-1 downto 0);
signal del_en			: std_logic_vector(NFFT-2 downto 0);
signal del_vl			: std_logic_vector(NFFT-2 downto 0); 
 
type complex_WxN is array (NFFT-2 downto 0) of std_logic_vector(2*Nwidth-1 downto 0);
signal di_aa 			: complex_WxN;
signal di_bb 			: complex_WxN;  
signal do_aa 			: complex_WxN;
signal do_bb 			: complex_WxN;

signal coe_en			: std_logic_vector(NFFT-1 downto 0);

begin
	
rstp <= not reset when rising_edge(clk);
	
bfly_en(0) <= data_en;
ia(0) <= data_in0;
ib(0) <= data_in1;

CALC_STAGE: for ii in 0 to NFFT-1 generate	
	signal butter_din_en_z	: std_logic_vector(15 downto 0);
begin

	oa2(ii) 	 <= ia(ii);   	
	ob2(ii) 	 <= ib(ii); 
	bfly_vl2(ii) <= bfly_en(ii);

	BUTTERFLY: entity work.fp23_ibfly_inv
		generic map (
			STAGE		=> ii,
			XSERIES		=> XSERIES,
			USE_CONJ	=> use_conj
		)
		port map(
			dt_ia      => iax(ii), 
			dt_ib      => ibx(ii),
			di_en      => bfly_enx(ii),
			ww         => ww(ii),
			dt_oa      => oa1(ii), 
			dt_ob      => ob1(ii),
			do_vl      => bfly_vl1(ii),
			reset  		=> reset,
			clk 		=> clk
		);


	COE_ROM: entity work.rom_twiddle_gen
		generic map(
			NFFT		=> NFFT,
			STAGE		=> NFFT-1-ii,
			XSERIES		=> XSERIES,
			USE_SCALE	=> USE_SCALE
		)
		port map(
			ww			=> ww(ii),
			clk 		=> clk,
			ww_ena 		=> coe_en(ii),
			reset  		=> reset
		);

	xALIGNE: entity work.fp23ifft_align_data
		generic map (
			NFFT		=> NFFT,
			STAGE 		=> ii,
			USE_SCALE	=> USE_SCALE
		)
		port map (	
			clk			=> clk,
			ia			=> ia(ii),
			ib			=> ib(ii),
			iax			=> iax(ii),
			ibx			=> ibx(ii),
			bfly_en		=> bfly_en(ii),
			bfly_enx	=> bfly_enx(ii)
		);			
			
	coe_en(ii) <= bfly_en(ii);	
	
	pr_xd: process(clk) is
	begin
		if rising_edge(clk) then
			if (use_fly = '1') then
				bfly_vl(ii) <= bfly_vl1(ii);
				oa(ii) <= oa1(ii); 
				ob(ii) <= ob1(ii); 
			else		
				bfly_vl(ii) <= bfly_vl2(ii);
				oa(ii) <= oa2(ii); 
				ob(ii) <= ob2(ii);  
			end if;
		end if;
	end process;
	
end generate;


DELAY_STAGE: for ii in 0 to NFFT-2 generate 	
	di_aa(ii) <= (oa(ii).im.exp & oa(ii).im.sig & oa(ii).im.man & oa(ii).re.exp & oa(ii).re.sig & oa(ii).re.man);	
	di_bb(ii) <= (ob(ii).im.exp & ob(ii).im.sig & ob(ii).im.man & ob(ii).re.exp & ob(ii).re.sig & ob(ii).re.man);	
	del_en(ii) <= bfly_vl(ii);
	
	DELAY_LINE : entity work.fp_delay_line_m1
		generic map(
			Nwidth		=> 2*Nwidth,
			NFFT		=> NFFT,
			stage		=> NFFT-2-ii
		)
		port map (
			ia 			=> di_aa(ii),
			ib 			=> di_bb(ii),
			din_en 		=> del_en(ii),
			oa 			=> do_aa(ii),
			ob 			=> do_bb(ii),
			dout_val	=> del_vl(ii),
			reset 		=> reset,
			clk 		=> clk
		); 
		
	ia(ii+1).re <= (do_aa(ii)(1*Nwidth-1 downto 0*Nwidth+Nman+1), do_aa(ii)(0*Nwidth+Nman), do_aa(ii)(0*Nwidth+Nman-1 downto 000000));
	ia(ii+1).im <= (do_aa(ii)(2*Nwidth-1 downto 1*Nwidth+Nman+1), do_aa(ii)(1*Nwidth+Nman), do_aa(ii)(1*Nwidth+Nman-1 downto Nwidth));
	ib(ii+1).re <= (do_bb(ii)(1*Nwidth-1 downto 0*Nwidth+Nman+1), do_bb(ii)(0*Nwidth+Nman), do_bb(ii)(0*Nwidth+Nman-1 downto 000000));
	ib(ii+1).im <= (do_bb(ii)(2*Nwidth-1 downto 1*Nwidth+Nman+1), do_bb(ii)(1*Nwidth+Nman), do_bb(ii)(1*Nwidth+Nman-1 downto Nwidth));	
	bfly_en(ii+1) <= del_vl(ii); 				
end generate;	  

pr_out: process(clk) is
begin
	if rising_edge(clk) then
		if (rstp = '1') then
			dout_val <= '0';
			dout0 <= (others => ("000000", '0', x"0000"));
			dout1 <= (others => ("000000", '0', x"0000"));	
		else
			 dout_val <= bfly_vl(NFFT-1);
			 dout0 <= oa(NFFT-1);
			 dout1 <= ob(NFFT-1); 
		end if;
	end if;
end process;

end fp23_ifftNk;