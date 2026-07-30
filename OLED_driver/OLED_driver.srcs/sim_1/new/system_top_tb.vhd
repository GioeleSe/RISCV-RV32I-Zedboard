library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity system_top_tb is
end entity system_top_tb;

architecture behavioral of system_top_tb is

    constant CLOCK_PERIOD : time := 10 ns; -- 100 MHz clock standard for Zedboard

    -- Testbench signals
    signal tb_clock     : std_logic := '0';
    signal tb_reset     : std_logic := '1';
    signal tb_btn_up    : std_logic := '0';
    signal tb_btn_down  : std_logic := '0';
    signal tb_btn_left  : std_logic := '0';
    signal tb_btn_right : std_logic := '0';

    -- OLED physical outputs
    signal oled_sdin    : std_logic;
    signal oled_sclk    : std_logic;
    signal oled_dc      : std_logic;
    signal oled_res     : std_logic;
    signal oled_vbat    : std_logic;
    signal oled_vdd     : std_logic;

begin

    -- Instantiate the System Top-Level
    uut: entity work.system_top
        port map (
            clock       => tb_clock,
            reset       => tb_reset,
            btn_up      => tb_btn_up,
            btn_down    => tb_btn_down,
            btn_left    => tb_btn_left,
            btn_right   => tb_btn_right,
            oled_sdin   => oled_sdin,
            oled_sclk   => oled_sclk,
            oled_dc     => oled_dc,
            oled_res    => oled_res,
            oled_vbat   => oled_vbat,
            oled_vdd    => oled_vdd
        );

    -- Clock Generation Process (100 MHz)
    p_clock : process
    begin
        loop
            tb_clock <= '0';
            wait for CLOCK_PERIOD / 2;
            tb_clock <= '1';
            wait for CLOCK_PERIOD / 2;
        end loop;
    end process;

    -- Stimulus Process
    p_stimulus : process
    begin
        -- Initial reset sequence
        tb_reset <= '1';
        tb_btn_up <= '0';
        tb_btn_right <= '0';
        wait for 50 ns;
        
        tb_reset <= '0'; -- Release reset, CPU starts fetching instructions
        
        -- Let the OLED initializer run through its startup configuration sequence
        wait for 2 ms;

        -- Simulate user pressing the "Right" button to move the box coordinates
        tb_btn_right <= '1';
        wait for 100 ns;
        tb_btn_right <= '0';
        
        wait for 1 ms;

        -- Simulate user pressing the "Up" button
        tb_btn_up <= '1';
        wait for 100 ns;
        tb_btn_up <= '0';

        wait;
    end process;

end architecture behavioral;