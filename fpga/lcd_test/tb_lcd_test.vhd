LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY tb_lcd_test IS
END tb_lcd_test;

ARCHITECTURE Behavioral OF tb_lcd_test IS

    COMPONENT lcd_test IS
        GENERIC (
            CLK_PERIOD_NS : POSITIVE := 20); -- 50MHz

        PORT ( CLOCK_50 : IN  STD_LOGIC;
               KEY      : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
               GPIO_0   : OUT STD_LOGIC_VECTOR(17 DOWNTO 2) );
    END COMPONENT;

    SIGNAL clk, lcd_rs, lcd_rw, lcd_e : STD_LOGIC;
    SIGNAL reset_n  : STD_LOGIC_VECTOR(0 DOWNTO 0);
    SIGNAL lcd_data : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL output   : STD_LOGIC_VECTOR(17 DOWNTO 2);

BEGIN
    lcd_e    <= output(6);
    lcd_rs   <= output(2);
    lcd_rw   <= output(4);
    lcd_data <= output(17 DOWNTO 14);

    LCD : lcd_test PORT MAP (
        CLOCK_50 => clk,
        KEY      => reset_n,
        GPIO_0   => output);
 
    clock: PROCESS
    BEGIN
        clk <= '0'; wait for 10 ns;
        clk <= '1'; wait for 10 ns;
    END PROCESS;

    reset: PROCESS
    BEGIN
        reset_n(0) <= '0'; wait for 100 ns;
        reset_n(0) <= '1'; wait;
    END PROCESS;
    
END Behavioral;
