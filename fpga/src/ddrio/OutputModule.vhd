library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity OutputModule is
	generic (
		-- Number of sysclk cycles to delay output DQS
		DQS_DELAY: natural
	);
	port (
		sysclk	: in std_logic;				-- System clock
		en		: in std_logic;				-- Enable registers
		rst		: in std_logic;				-- Synchronous reset
		oe		: in std_logic;

		D		: in signed(7 downto 0);	-- Data
		mask	: in std_logic;				-- Data mask
		DDR_D	: out signed(7 downto 0);	-- Output data	(TriState)
		DDR_mask: out std_logic;			-- Output data mask

		DQS		: in std_logic;				-- DQS
		DDR_DQS : out std_logic				-- Output DQS (TriState)
	);
end entity OutputModule;

architecture RTL_Pipelined of OutputModule is
	component FlipFlopD is
		port (
			clk	: in std_logic;		-- Clcok signal
			en 	: in std_logic;		-- Enable
			rst	: in std_logic;		-- Synchronous reset
			prst: in std_logic;		-- Synchronous preset
			D	: in std_logic;		-- Data
			Q	: out std_logic		-- Output
		);
	end component;
	component RegisterSigned is
		generic(
			N : natural
		);
		port (
			clk: in std_logic;				-- Clock
			rst: in std_logic;				-- Reset
			en : in std_logic;				-- Enable
			D  : in signed(N-1 downto 0);	-- Data input
			Q  : out signed(N-1 downto 0)	-- Data output
		);
	end component;
	component TriStateDriver is
		port (
			A: 	in std_logic;		-- Data
			oe: in std_logic;		-- Output enable
			Y: out std_logic		-- Output
		);
	end component;

	signal synch_oe: std_logic;
	signal synch_D: signed(7 downto 0);
	signal synch_DQS: std_logic;
	signal tmp_DQS: std_logic_vector(0 to DQS_DELAY+1);

begin
	-- D Flip Flop to synchronize OE with data
	comp_oe_ff: FlipFlopD
		port map (sysclk, en, rst, '0', oe, synch_oe);
	-- D Flip Flop to synchronize mask
	comp_mask_ff: FlipFlopD
		port map (sysclk, en, rst, '0', mask, DDR_mask);

	-- Signed register to synchronize data
	comp_reg_q: RegisterSigned
		generic map (8)
		port map (sysclk, '0', en, D, synch_D);

	-- Output tri state drivers
	gen_q_tristates: for i in 0 to 7 generate
		comp_q_tsd_i: TriStateDriver
			port map(synch_D(i), synch_oe, DDR_D(i));
	end generate;

	---- DQS delay line
	-- First mandatory flip flop
	comp_dqs_ff0: FlipFlopD
		port map(sysclk, en, rst, '0', DQS, synch_DQS);
	tmp_DQS(0) <= synch_DQS;
	-- Delay flipflops
	gen_dqs_ffs: for i in 0 to DQS_DELAY generate
		comp_dqs_ff_i: FlipFlopD
			-- These flipflops are always enabled since they only serve as a
			-- delay
			port map (sysclk, '1', rst, '0', tmp_DQS(i), tmp_DQS(i+1));
	end generate;
	-- Put tri state driver on DQS output as well
	comp_dqs_tsd: TriStateDriver
		port map (tmp_DQS(DQS_DELAY + 1), synch_oe, DDR_DQS);
end architecture RTL_Pipelined;


-- *************** Configurations ***************
use work.all;
configuration CONF_Default of OutputModule is
	for RTL_Pipelined
		-- Simple flip flop for the mask
		for comp_mask_ff: FlipFlopD
			use entity work.FlipFlopD(RisingEdge);
		end for;
		-- Simple flip flop for DQS synchronization
		for comp_dqs_ff0: FlipFlopD
			use entity work.FlipFlopD(RisingEdge);
		end for;
		-- Asynchronous resrt falling edge FFs for DQS delay line
		for gen_dqs_ffs
			for all: FlipFlopD
				use entity work.FlipFlopD(AsynchRstFallingEdge);
			end for;
		end for;
		-- Tri state drivers' output enable should have asynchrnous reset to
		-- avoid short circuits on the bus
		for comp_oe_ff: FlipFlopD
			use entity work.FlipFlopD(AsynchRstRisingEdge);
		end for;
	end for;
end configuration CONF_Default;
