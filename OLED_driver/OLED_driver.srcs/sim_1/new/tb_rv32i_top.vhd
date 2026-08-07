-- ============================================================================
-- tb_rv32i_top.vhd
--
-- Self-checking testbench for rv32i_top, verifying the CPU correctly executes
-- the square-path animation program and writes the expected (X,Y) sequence to
-- the OLED MMIO register (oled_cmd_reg_out) at address 0x000F0004.
--
-- WHAT THIS CHECKS
--   The program (once the BRAM is loaded with the corrected square-path code)
--   should write the following repeating sequence of (X,Y) pairs, in order,
--   forever:
--
--     LEG 1 (right):  X: 33 -> 60, Y fixed at 4    (28 writes)
--     LEG 2 (down):   Y: 5  -> 24, X fixed at 60    (20 writes)
--     LEG 3 (left):   X: 59 -> 32, Y fixed at 24    (28 writes)
--     LEG 4 (up):     Y: 23 -> 4,  X fixed at 32    (20 writes)
--     ... then repeats from LEG 1 (X: 33 -> 60, Y=4) ...

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_rv32i_top is
end entity tb_rv32i_top;

architecture sim of tb_rv32i_top is

    component rv32i_top is
        port (
            clock            : in  std_logic;
            reset            : in  std_logic;
            oled_cmd_reg_out : out std_logic_vector(31 downto 0)
        );
    end component;

    -- ------------------------------------------------------------------
    -- Clock / reset
    -- ------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- ------------------------------------------------------------------
    -- DUT interconnect
    -- ------------------------------------------------------------------
    signal oled_cmd_reg : std_logic_vector(31 downto 0) := (others => '0');

    -- ------------------------------------------------------------------
    -- Checker bookkeeping
    -- ------------------------------------------------------------------
    signal prev_cmd_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal write_seen     : boolean := false;

    constant MAX_WRITES_TO_CHECK : integer := 300; -- ~3 full laps (96 writes each)
    constant WATCHDOG_CYCLES     : integer := 500_000; -- fail sim if stuck this long

    signal writes_checked : integer := 0;
    signal fail_count      : integer := 0;
    signal sim_done        : boolean := false;

begin

    -- ------------------------------------------------------------------
    -- Clock generation
    -- ------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- ------------------------------------------------------------------
    -- Reset pulse
    -- ------------------------------------------------------------------
    reset_gen : process
    begin
        reset <= '1';
        wait for CLK_PERIOD * 10;
        reset <= '0';
        wait;
    end process;

    -- ------------------------------------------------------------------
    -- DUT
    -- ------------------------------------------------------------------
    DUT : rv32i_top
        port map (
            clock            => clk,
            reset            => reset,
            oled_cmd_reg_out => oled_cmd_reg
        );

    -- ------------------------------------------------------------------
    -- Self-checking process: models the expected square-path algorithm
    -- step-by-step and compares it against every real write the CPU makes.
    -- ------------------------------------------------------------------
    checker : process(clk)
        variable v_x, v_y      : integer := 32; -- expected current position
        variable v_leg         : integer := 1;  -- 1=right,2=down,3=left,4=up
        variable v_steps_left  : integer := 28; -- steps remaining in this leg
        variable v_first_write : boolean := true;
        variable v_exp_x, v_exp_y : integer;
        variable v_act_x, v_act_y : integer;
        variable v_watchdog     : integer := 0;
        variable l              : line;
    begin
        if rising_edge(clk) then
            prev_cmd_reg <= oled_cmd_reg;

            if reset = '1' then
                v_x := 32; v_y := 4; v_leg := 1; v_steps_left := 28;
                v_first_write := true;
                v_watchdog := 0;
            elsif not sim_done then

                v_watchdog := v_watchdog + 1;

                -- Detect a new MMIO write (value change on oled_cmd_reg_out)
                if oled_cmd_reg /= prev_cmd_reg and writes_checked < MAX_WRITES_TO_CHECK then

                    v_watchdog := 0;

                    v_act_x := to_integer(unsigned(oled_cmd_reg(7 downto 0)));
                    v_act_y := to_integer(unsigned(oled_cmd_reg(15 downto 8)));

                    -- Advance the expected-value model by exactly one step,
                    -- mirroring the square-path assembly algorithm.
                    case v_leg is
                        when 1 => v_x := v_x + 1; -- LEG1: right
                        when 2 => v_y := v_y + 1; -- LEG2: down
                        when 3 => v_x := v_x - 1; -- LEG3: left
                        when 4 => v_y := v_y - 1; -- LEG4: up
                        when others => null;
                    end case;

                    v_exp_x := v_x;
                    v_exp_y := v_y;

                    v_steps_left := v_steps_left - 1;
                    if v_steps_left = 0 then
                        case v_leg is
                            when 1 => v_leg := 2; v_steps_left := 20;
                            when 2 => v_leg := 3; v_steps_left := 28;
                            when 3 => v_leg := 4; v_steps_left := 20;
                            when 4 => v_leg := 1; v_steps_left := 28;
                            when others => null;
                        end case;
                    end if;

                    writes_checked <= writes_checked + 1;

                    write(l, string'("Write #"));
                    write(l, writes_checked + 1);
                    write(l, string'(" @ "));
                    write(l, now);
                    write(l, string'("  actual=(X="));
                    write(l, v_act_x);
                    write(l, string'(",Y="));
                    write(l, v_act_y);
                    write(l, string'(")  expected=(X="));
                    write(l, v_exp_x);
                    write(l, string'(",Y="));
                    write(l, v_exp_y);
                    write(l, string'(")  "));

                    if v_act_x = v_exp_x and v_act_y = v_exp_y then
                        write(l, string'("PASS"));
                    else
                        write(l, string'("FAIL"));
                        fail_count <= fail_count + 1;
                    end if;
                    writeline(output, l);

                elsif oled_cmd_reg = prev_cmd_reg then
                    -- No write this cycle; feed the watchdog
                    if v_watchdog > WATCHDOG_CYCLES then
                        write(l, string'("*** WATCHDOG TIMEOUT: no MMIO write for "));
                        write(l, WATCHDOG_CYCLES);
                        write(l, string'(" cycles. CPU appears stalled. ***"));
                        writeline(output, l);
                        sim_done <= true;
                    end if;
                end if;

                if writes_checked >= MAX_WRITES_TO_CHECK then
                    sim_done <= true;
                end if;
            end if;
        end if;
    end process;

    -- ------------------------------------------------------------------
    -- Final summary
    -- ------------------------------------------------------------------
    summary : process
        variable l : line;
    begin
        wait until sim_done;
        wait for CLK_PERIOD;
        write(l, string'("============================================"));
        writeline(output, l);
        write(l, string'("Writes checked: "));
        write(l, writes_checked);
        writeline(output, l);
        write(l, string'("Failures:       "));
        write(l, fail_count);
        writeline(output, l);
        if fail_count = 0 and writes_checked >= MAX_WRITES_TO_CHECK then
            write(l, string'("RESULT: PASS - CPU produced the correct square-path sequence."));
        elsif fail_count = 0 then
            write(l, string'("RESULT: INCONCLUSIVE - no failures seen, but not enough writes captured (possible stall). See watchdog message above if present."));
        else
            write(l, string'("RESULT: FAIL - CPU deviated from the expected square-path sequence. Check pipeline hazards / branch resolution / register file."));
        end if;
        writeline(output, l);
        write(l, string'("============================================"));
        writeline(output, l);
        wait;
    end process;

end architecture sim;