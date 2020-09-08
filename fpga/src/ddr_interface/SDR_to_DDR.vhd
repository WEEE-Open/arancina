-- Transform an input Single Data Rate signal (with double parallelism) into a
-- Double Data Rate signal.

-- In the SDR domain, data is considered to have twice the normal parallelism.
-- The first half is associated to the clock's positive edge, the second half
-- is associated to the negative edge.
-- Output is latched with the en signal
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SDR_to_DDR is
	generic (
		N : natural									-- Data parallelism
	);
	port (
		clk : in std_logic;							-- Clock
		en  : in std_logic;							-- Output enable
		DQS : out std_logic;						-- DQS for output sampling
		SDR_in_posedge: in signed(N-1 downto 0);	-- Input data associated to positive clock
		SDR_in_negedge: in signed(N-1 downto 0);	-- Input data associated to negative clock
		DDR_out		  : out signed(N-1 downto 0)	-- Output DDR
	);
end entity SDR_to_DDR;

architecture RTL of SDR_to_DDR is
	signal mux_out: signed(N-1 downto 0);
begin
	with clk select mux_out <=
		SDR_in_posedge when '1',
		SDR_in_negedge when others;

	proc_output_latch: process(en, mux_out)
	 	if en = '1' then
			DDR_out <= mux_out;
		end if;
	end process proc_output_latch;

	-- TODO: fix DQS for better output sampling?
	DQS <= clk;
end architecture RTL;
