library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity DDRMem is
	generic (
		ADDR_WIDTH : natural;
		DATA_WIDTH : natural;

		CL: natural		-- CAS Latency
		BL: natural 	-- Burst length
	);
	port (
		-- Control
		clk : in std_logic;
		_cs, _we, _ras, _cas : in std_logic;

		-- Data
		addr: in unsigned(ADDR_WIDTH-1 downto 0);
		DQ  : inout signed(DATA_WIDTH-1 downto 0);
		DQS : inout std_logic_vector(DATA_WIDTH/8-1 downto 0)
	);
end entity DDRMem;


architecture Behavior of DDRMem is
	type t_mem is array(0 to 2**(ADDR_WIDTH*2) - 1)
		of signed(DATA_WIDTH-1 downto 0);
	signal mem : t_mem;

	-- Command, the concatenation of _CS, _RAS, _CAS, _WE
	type t_cmd is std_logic_vector(0 to 3);
	signal 		cmd: t_cmd;
	constant 	cNOP	: t_cmd := "0111";
	constant 	cACTIVE : t_cmd := "0011";
	constant	cREAD	: t_cmd := "0101";
	constant 	cWRITE	: t_cmd := "0100";

	signal addr_internal : unsigned(2*ADDR_WIDTH - 1 downto 0);
	signal addr_row: unsigned(ADDR_WIDTH - 1 downto 0);
	signal addr_col: unsigned(ADDR_WIDTH - 1 downto 0)

begin
	cmd <= _cs & _ras & _cas & _we;
	addr_internal <= addr_row & addr_col;

	proc_mem: process
	begin
		wait until rising_edge(clk);
		-- Data is Z by default
		DQ <= (others => 'Z');

		-- Check memory is enabled
		if _cs = '0' then
			-- Process command
			case cmd is
				when cNOP => -- Do nothing
				when cACTIVE =>
					-- Select row
					addr_row <= addr;
				when cREAD =>
					addr_col <= addr;
					-- Wait for CL clock cycles:
					for i in 0 to CL loop
						wait until rising_edge(clk);
					end loop;
					-- Output burst
					for i in 0 to BL loop
						DQ <= mem(to_integer(addr_internal));
						wait until falling_edge(clk) or rising_edge(clk);
					end loop;
					DQ <= 'Z';
				when cWRITE =>
					-- Input burst
					for i in 0 to BL loop
						mem(to_integer(addr_internal)) <= DQ;
						wait until falling_edge(clk) or rising_edge(clk);
					end loop;
			end case;
		end if;
	end process proc_mem;
end architecture Behavior;
