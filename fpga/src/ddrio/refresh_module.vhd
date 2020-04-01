library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity refresh_module is
	generic (
		N : natural := 11
	);
	port (
		clk:   in std_logic;					-- Clock
		c_en:  in std_logic;					-- Count enable
		
		rst_cnt:   in std_logic;			-- Reset counter
		rst_rfr:   in std_logic;			-- Reset output
		
		cnt:  in unsigned(N-1 downto 0);			-- Parallel in
		refresh: out std_logic						-- Count
	);
end entity refresh_module;


architecture Behavior of refresh_module is

	-- Internal register
	signal s_cnt: unsigned(N-1 downto 0);
	signal s_rfr: std_logic;
	signal s_tollerance: unsigned(N-2 downto 0);
	signal s_TC: unsigned(N-1 downto 0);
	
begin

gen_tollerance: for k in N-2 downto 0 generate
	s_tollerance(k) <= cnt(k+1);
end generate;	

s_TC <= cnt - s_tollerance;


proc_control_cnt: process(clk)
	begin
	
		if (clk 'event and clk = '1') then
			if rst_cnt = '1' then
				s_cnt <= (others => '0');
			elsif c_en = '1' then
				s_cnt <= s_cnt + "1";
			end if;
		end if;
		
end process proc_control_cnt;	
	

proc_TC_cnt: process(clk)
	begin
	
		if (clk'event and clk = '1') then
			if s_cnt >= s_TC then
				s_rfr <= '1';
			end if;
			if rst_rfr = '1' then
				s_rfr <= '0';
			end if;
		end if;
		
end process proc_TC_cnt;
	
	refresh <= s_rfr;

	
	end architecture Behavior;