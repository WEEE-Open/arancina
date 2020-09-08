-- Transform a Double Data Rate signal into a Single Data Rate signal (with
-- twice the data width).

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity DDR_to_SDR is
	generic (
		N : unsigned	-- Data parallelism
	);
	port (
		DQS    : in std_logic;				-- DQS (sampling signal)
		en	   : in std_logic;				-- enable
		DDR_in : in signed(N-1 downto 0);	-- DDR channel
		SDR_out_posedge : out signed(N - 1 downto 0);	-- Output channel 1
		SDR_out_negedge : out signed(N - 1 downto 0)	-- Output channel 0
	);
end entity DDR_to_SDR;


architecture RTL of DDR_to_SDR is
begin
	proc_posedge: process(DQS)
	begin
		if rising_edge(DQS) then
			if en = '1' then
				SDR_out_posedge <= DDR_in;
			end if;
		end if;
	end process proc_posedge;

	proc_negedge: process(DQS)
	begin
		if rising_edge(DQS) then
			if en = '1' then
				SDR_out_negedge <= DDR_in;
			end if;
		end if;
	end process proc_negedge;
end architecture RTL;
