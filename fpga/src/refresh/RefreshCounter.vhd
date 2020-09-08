library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RefreshCounter is
	generic (
		N: natural	-- Counter's number of bits
	);
	port (
		clk : in std_logic;
		cen: in std_logic;
		rst: in std_logic;

		tcval: in unsigned(N-1 downto 0);

		refresh: out std_logic
	);
end entity RefreshCounter;

architecture RTL of RefreshCounter is
	component Counter is
		generic (
			N : natural
		);
		port (
			clk:  in std_logic;					-- Clock
			cen:  in std_logic;					-- Count enable
			rst:  in std_logic;					-- Reset
			pl:   in std_logic;					-- Parallel load
			pin:  in unsigned(N-1 downto 0);	-- Parallel in
			cnt: out unsigned(N-1 downto 0)		-- Count
		);
	end component;

	signal tc, internal_enable : std_logic;
	signal cnt : unsigned(N-1 downto 0);
begin
	-- Stop the counter if it reached tc
	internal_enable <= cen and not tc;
	comp_counter: Counter
		generic map (N)
		port map (clk, internal_enable, rst, '0', (others => '0'), cnt);


end architecture RTL;
