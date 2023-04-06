-- Based on https://github.com/james-sakalaukus/VHDL_LCD_Controller_20x4
-- With minor modifications

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY lcd20x4_ctrl IS

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

END ENTITY lcd20x4_ctrl;

ARCHITECTURE rtl OF lcd20x4_ctrl IS

    CONSTANT DELAY_15_MS : POSITIVE := 15 * 10 ** 6 / CLK_PERIOD_NS + 1;
    CONSTANT DELAY_1640_US : POSITIVE := 1640 * 10 ** 3 / CLK_PERIOD_NS + 1;
    CONSTANT DELAY_4100_US : POSITIVE := 4100 * 10 ** 3 / CLK_PERIOD_NS + 1;
    CONSTANT DELAY_100_US : POSITIVE := 100 * 10 ** 3 / CLK_PERIOD_NS + 1;
    CONSTANT DELAY_40_US : POSITIVE := 40 * 10 ** 3 / CLK_PERIOD_NS + 1;

    CONSTANT DELAY_NIBBLE : POSITIVE := 10 ** 3 / CLK_PERIOD_NS + 1;
    CONSTANT DELAY_LCD_E : POSITIVE := 230 / CLK_PERIOD_NS + 1;
    CONSTANT DELAY_SETUP_HOLD : POSITIVE := 40 / CLK_PERIOD_NS + 1;

    CONSTANT MAX_DELAY : POSITIVE := DELAY_15_MS;

    -- this record describes one write operation
    TYPE op_t IS RECORD
        rs : STD_LOGIC;
        data : STD_LOGIC_VECTOR(7 DOWNTO 0);
        delay_h : INTEGER RANGE 0 TO MAX_DELAY;
        delay_l : INTEGER RANGE 0 TO MAX_DELAY;
    END RECORD op_t;
    CONSTANT default_op : op_t := (rs => '1', data => X"00", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US);
    CONSTANT op_select_line1 : op_t := (rs => '0', data => X"80", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US);
    CONSTANT op_select_line2 : op_t := (rs => '0', data => X"C0", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US);
    CONSTANT op_select_line3 : op_t := (rs => '0', data => X"94", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US);
    CONSTANT op_select_line4 : op_t := (rs => '0', data => X"D4", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US);

    -- init + config operations:
    -- write 3 x 0x3 followed by 0x2
    -- function set command
    -- entry mode set command
    -- display on/off command
    -- clear display
    TYPE config_ops_t IS ARRAY(0 TO 5) OF op_t;
    CONSTANT config_ops : config_ops_t
    := (5 => (rs => '0', data => X"33", delay_h => DELAY_4100_US, delay_l => DELAY_100_US),
    4 => (rs => '0', data => X"32", delay_h => DELAY_40_US, delay_l => DELAY_40_US),
    3 => (rs => '0', data => X"28", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US),
    2 => (rs => '0', data => X"06", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US),
    1 => (rs => '0', data => X"0C", delay_h => DELAY_NIBBLE, delay_l => DELAY_40_US),
    0 => (rs => '0', data => X"01", delay_h => DELAY_NIBBLE, delay_l => DELAY_1640_US));

    SIGNAL this_op : op_t;

    TYPE op_state_t IS (IDLE,
        WAIT_SETUP_H,
        ENABLE_H,
        WAIT_HOLD_H,
        WAIT_DELAY_H,
        WAIT_SETUP_L,
        ENABLE_L,
        WAIT_HOLD_L,
        WAIT_DELAY_L,
        DONE);

    SIGNAL op_state : op_state_t := DONE;
    SIGNAL next_op_state : op_state_t;
    SIGNAL cnt : NATURAL RANGE 0 TO MAX_DELAY;
    SIGNAL next_cnt : NATURAL RANGE 0 TO MAX_DELAY;

    TYPE state_t IS (RESET,
        CONFIG,
        SELECT_LINE1,
        WRITE_LINE1,
        SELECT_LINE2,
        WRITE_LINE2,
        SELECT_LINE3,
        WRITE_LINE3,
        SELECT_LINE4,
        WRITE_LINE4);

    SIGNAL state : state_t := RESET;
    SIGNAL next_state : state_t;
    SIGNAL ptr : NATURAL RANGE 0 TO 19 := 0;
    SIGNAL next_ptr : NATURAL RANGE 0 TO 19;

BEGIN

    proc_state : PROCESS (state, op_state, ptr, line1_buffer, line2_buffer, line3_buffer, line4_buffer) IS
    BEGIN
        CASE state IS
            WHEN RESET =>
                this_op <= default_op;
                next_state <= CONFIG;
                next_ptr <= config_ops_t'high;

            WHEN CONFIG =>
                this_op <= config_ops(ptr);
                next_ptr <= ptr;
                next_state <= CONFIG;
                IF op_state = DONE THEN
                    IF ptr = 0 THEN
                        next_ptr <= 19;
                        next_state <= SELECT_LINE1;
                    ELSE
                        next_ptr <= ptr - 1;
                    END IF;
                END IF;

            WHEN SELECT_LINE1 =>
                this_op <= op_select_line1;
                next_ptr <= 19;
                IF op_state = DONE THEN
                    next_state <= WRITE_LINE1;
                ELSE
                    next_state <= SELECT_LINE1;
                END IF;

            WHEN WRITE_LINE1 =>
                this_op <= default_op;
                this_op.data <= line1_buffer(ptr * 8 + 7 DOWNTO ptr * 8);
                next_ptr <= ptr;
                next_state <= WRITE_LINE1;
                IF op_state = DONE THEN
                    IF ptr = 0 THEN
                        next_ptr <= 19;
                        next_state <= SELECT_LINE2;
                    ELSE
                        next_ptr <= ptr - 1;
                    END IF;
                END IF;

            WHEN SELECT_LINE2 =>
                this_op <= op_select_line2;
                next_ptr <= 19;
                IF op_state = DONE THEN
                    next_state <= WRITE_LINE2;
                ELSE
                    next_state <= SELECT_LINE2;
                END IF;

            WHEN WRITE_LINE2 =>
                this_op <= default_op;
                this_op.data <= line2_buffer(ptr * 8 + 7 DOWNTO ptr * 8);
                next_ptr <= ptr;
                next_state <= WRITE_LINE2;
                IF op_state = DONE THEN
                    IF ptr = 0 THEN
                        next_ptr <= 19;
                        next_state <= SELECT_LINE3;
                    ELSE
                        next_ptr <= ptr - 1;
                    END IF;
                END IF;

            WHEN SELECT_LINE3 =>
                this_op <= op_select_line3;
                next_ptr <= 19;
                IF op_state = DONE THEN
                    next_state <= WRITE_LINE3;
                ELSE
                    next_state <= SELECT_LINE3;
                END IF;

            WHEN WRITE_LINE3 =>
                this_op <= default_op;
                this_op.data <= line3_buffer(ptr * 8 + 7 DOWNTO ptr * 8);
                next_ptr <= ptr;
                next_state <= WRITE_LINE3;
                IF op_state = DONE THEN
                    IF ptr = 0 THEN
                        next_ptr <= 19;
                        next_state <= SELECT_LINE4;
                    ELSE
                        next_ptr <= ptr - 1;
                    END IF;
                END IF;

            WHEN SELECT_LINE4 =>
                this_op <= op_select_line4;
                next_ptr <= 19;
                IF op_state = DONE THEN
                    next_state <= WRITE_LINE4;
                ELSE
                    next_state <= SELECT_LINE4;
                END IF;

            WHEN WRITE_LINE4 =>
                this_op <= default_op;
                this_op.data <= line4_buffer(ptr * 8 + 7 DOWNTO ptr * 8);
                next_ptr <= ptr;
                next_state <= WRITE_LINE4;
                IF op_state = DONE THEN
                    IF ptr = 0 THEN
                        next_ptr <= 19;
                        next_state <= SELECT_LINE1;
                    ELSE
                        next_ptr <= ptr - 1;
                    END IF;
                END IF;

        END CASE;
    END PROCESS proc_state;

    reg_state : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state <= RESET;
                ptr <= 0;
            ELSE
                state <= next_state;
                ptr <= next_ptr;
            END IF;
        END IF;
    END PROCESS reg_state;

    -- we never read from the lcd
    lcd_rw <= '0';

    proc_op_state : PROCESS (op_state, cnt, this_op) IS
    BEGIN
        CASE op_state IS
            WHEN IDLE =>
                lcd_db <= (OTHERS => '0');
                lcd_rs <= '0';
                lcd_e <= '0';
                next_op_state <= WAIT_SETUP_H;
                next_cnt <= DELAY_SETUP_HOLD;

            WHEN WAIT_SETUP_H =>
                lcd_db <= this_op.data(7 DOWNTO 4);
                lcd_rs <= this_op.rs;
                lcd_e <= '0';
                IF cnt = 0 THEN
                    next_op_state <= ENABLE_H;
                    next_cnt <= DELAY_LCD_E;
                ELSE
                    next_op_state <= WAIT_SETUP_H;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN ENABLE_H =>
                lcd_db <= this_op.data(7 DOWNTO 4);
                lcd_rs <= this_op.rs;
                lcd_e <= '1';
                IF cnt = 0 THEN
                    next_op_state <= WAIT_HOLD_H;
                    next_cnt <= DELAY_SETUP_HOLD;
                ELSE
                    next_op_state <= ENABLE_H;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN WAIT_HOLD_H =>
                lcd_db <= this_op.data(7 DOWNTO 4);
                lcd_rs <= this_op.rs;
                lcd_e <= '0';
                IF cnt = 0 THEN
                    next_op_state <= WAIT_DELAY_H;
                    next_cnt <= this_op.delay_h;
                ELSE
                    next_op_state <= WAIT_HOLD_H;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN WAIT_DELAY_H =>
                lcd_db <= (OTHERS => '0');
                lcd_rs <= '0';
                lcd_e <= '0';
                IF cnt = 0 THEN
                    next_op_state <= WAIT_SETUP_L;
                    next_cnt <= DELAY_SETUP_HOLD;
                ELSE
                    next_op_state <= WAIT_DELAY_H;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN WAIT_SETUP_L =>
                lcd_db <= this_op.data(3 DOWNTO 0);
                lcd_rs <= this_op.rs;
                lcd_e <= '0';
                IF cnt = 0 THEN
                    next_op_state <= ENABLE_L;
                    next_cnt <= DELAY_LCD_E;
                ELSE
                    next_op_state <= WAIT_SETUP_L;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN ENABLE_L =>
                lcd_db <= this_op.data(3 DOWNTO 0);
                lcd_rs <= this_op.rs;
                lcd_e <= '1';
                IF cnt = 0 THEN
                    next_op_state <= WAIT_HOLD_L;
                    next_cnt <= DELAY_SETUP_HOLD;
                ELSE
                    next_op_state <= ENABLE_L;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN WAIT_HOLD_L =>
                lcd_db <= this_op.data(3 DOWNTO 0);
                lcd_rs <= this_op.rs;
                lcd_e <= '0';
                IF cnt = 0 THEN
                    next_op_state <= WAIT_DELAY_L;
                    next_cnt <= this_op.delay_l;
                ELSE
                    next_op_state <= WAIT_HOLD_L;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN WAIT_DELAY_L =>
                lcd_db <= (OTHERS => '0');
                lcd_rs <= '0';
                lcd_e <= '0';
                IF cnt = 0 THEN
                    next_op_state <= DONE;
                    next_cnt <= 0;
                ELSE
                    next_op_state <= WAIT_DELAY_L;
                    next_cnt <= cnt - 1;
                END IF;

            WHEN DONE =>
                lcd_db <= (OTHERS => '0');
                lcd_rs <= '0';
                lcd_e <= '0';
                next_op_state <= IDLE;
                next_cnt <= 0;

        END CASE;
    END PROCESS proc_op_state;

    reg_op_state : PROCESS (clk) IS
    BEGIN
        IF rising_edge(clk) THEN
            IF state = RESET THEN
                op_state <= IDLE;
            ELSE
                op_state <= next_op_state;
                cnt <= next_cnt;
            END IF;
        END IF;
    END PROCESS reg_op_state;
END ARCHITECTURE rtl;
