LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY lcd_test IS
    GENERIC (
        CLK_PERIOD_NS : POSITIVE := 20); -- 50MHz

    PORT ( CLOCK_50 : IN  STD_LOGIC;
           KEY      : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
           GPIO_0   : OUT STD_LOGIC_VECTOR(17 DOWNTO 2) );
END lcd_test;

ARCHITECTURE behavior OF lcd_test IS

    COMPONENT lcd20x4_ctrl IS
        GENERIC (
            CLK_PERIOD_NS : POSITIVE := 20); -- 50MHz

        PORT (
            clk : IN STD_LOGIC;
            rst : IN STD_LOGIC;
            lcd_e : OUT STD_LOGIC;
            lcd_rs : OUT STD_LOGIC;
            lcd_rw : OUT STD_LOGIC;
            lcd_db : OUT STD_LOGIC_VECTOR(7 DOWNTO 4);
            line1_buffer : IN STD_LOGIC_VECTOR(159 DOWNTO 0); -- 20x8bit
            line2_buffer : IN STD_LOGIC_VECTOR(159 DOWNTO 0);
            line3_buffer : IN STD_LOGIC_VECTOR(159 DOWNTO 0);
            line4_buffer : IN STD_LOGIC_VECTOR(159 DOWNTO 0));
    END COMPONENT;

    -- Reset signal
    SIGNAL rst : STD_LOGIC;
    
    -- Moving cursor signals
    CONSTANT TICK_125_MS : POSITIVE := 125 * 10 ** 6 / CLK_PERIOD_NS;
    SIGNAL cnt_tick : NATURAL RANGE 0 TO TICK_125_MS - 1 := 0;
    TYPE char_t IS (CHAR1, CHAR2, CHAR3, CHAR4);
    SIGNAL st_cur : char_t := CHAR1;
    SIGNAL cursor : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"2F";

    -- Progress bar (dummy) signals
    CONSTANT COUNTER_1_S : POSITIVE := 8; -- Multiple of TICK_125_MS
    SIGNAL cnt_pb : NATURAL RANGE 0 TO COUNTER_1_S - 1 := 0;
    SIGNAL ptr : NATURAL RANGE 0 TO 19 := 19;    

    -- Line buffer signals and default values
    CONSTANT LINE1_TEXT : STD_LOGIC_VECTOR(159 DOWNTO 0) := x"4172616E63696E61202D2057454545204F70656E";
    CONSTANT LINE2_TEXT : STD_LOGIC_VECTOR(159 DOWNTO 0) := x"54657374696E67204452414D20636869702E2E2E";
    CONSTANT LINE3_TEXT : STD_LOGIC_VECTOR(159 DOWNTO 0) := x"2020202020202020202020202020202020202020";
    CONSTANT LINE4_TEXT : STD_LOGIC_VECTOR(159 DOWNTO 0) := x"3C50524556202020202020202020204E4558543E";
	SIGNAL line1 : STD_LOGIC_VECTOR(159 DOWNTO 0) := LINE1_TEXT;
	SIGNAL line2 : STD_LOGIC_VECTOR(159 DOWNTO 0) := LINE2_TEXT;
    SIGNAL line3 : STD_LOGIC_VECTOR(159 DOWNTO 0) := LINE3_TEXT;
    SIGNAL line4 : STD_LOGIC_VECTOR(159 DOWNTO 0) := LINE4_TEXT;

BEGIN

    rst <= NOT(KEY(0));

    LCD: lcd20x4_ctrl PORT MAP (
        clk          => CLOCK_50,
        rst          => rst,
        lcd_e        => GPIO_0(6),
        lcd_rs       => GPIO_0(2),
        lcd_rw       => GPIO_0(4),
        lcd_db       => GPIO_0(17 downto 14),
        line1_buffer => line1,
        line2_buffer => line2,
        line3_buffer => line3,
        line4_buffer => line4 );

    rotating_cursor: PROCESS (CLOCK_50) IS
    BEGIN
        IF rising_edge(CLOCK_50) THEN
            IF rst = '1' THEN
                cnt_tick <= 0;
                st_cur <= CHAR1;
            ELSIF cnt_tick = TICK_125_MS - 1 THEN
                -- Switch between 4 positions, to have a rotating effect
                CASE st_cur IS
                    WHEN CHAR1 =>
                        cursor <= x"2F";
                        st_cur <= CHAR2;
                    WHEN CHAR2 =>
                        cursor <= x"2D";
                        st_cur <= CHAR3;
                    WHEN CHAR3 =>
                        cursor <= x"A4";
                        st_cur <= CHAR4;
                    WHEN CHAR4 =>
                        cursor <= x"7C";
                        st_cur <= CHAR1;
                END CASE;
                cnt_tick <= 0;
            ELSE
                cnt_tick <= cnt_tick + 1;            
            END IF;
        END IF;
    END PROCESS rotating_cursor;
    
    progress_bar: PROCESS (CLOCK_50) IS
    BEGIN
        IF rising_edge(CLOCK_50) THEN
            IF rst = '1' THEN
                line3 <= LINE3_TEXT;
                cnt_pb <= 0;
                ptr <= 19;
            ELSIF cnt_tick = TICK_125_MS - 1 THEN
                -- Use the rotating cursor at the position corresponding to the current progress
                line3(ptr * 8 + 7 DOWNTO ptr * 8) <= cursor;
                IF cnt_pb = COUNTER_1_S - 1 THEN
                    IF ptr = 0 THEN
                        line3 <= LINE3_TEXT;
                        ptr <= 19;
                    ELSE
                        -- Move the pointer to the following location and leave a mark
                        line3(ptr * 8 + 7 DOWNTO ptr * 8) <= x"3D";
                        ptr <= ptr - 1;
                    END IF;
                    cnt_pb <= 0;
                ELSE
                    cnt_pb <= cnt_pb + 1;
                END IF;
            END IF;

        END IF;
    END PROCESS progress_bar;
        
END ARCHITECTURE;
