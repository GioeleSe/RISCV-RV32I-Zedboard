library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity cpu_oled_top is
    Port (
        clock        : in  std_logic;
        reset        : in  std_logic;
        -- OLED physical outputs
        oled_sdin    : out std_logic;
        oled_sclk    : out std_logic;
        oled_dc      : out std_logic;
        oled_res     : out std_logic;
        oled_vbat    : out std_logic;
        oled_vdd     : out std_logic
    );
end entity cpu_oled_top;

architecture Behavioral of cpu_oled_top is

    -- Internal signals for MMIO and register communication
    signal s_oled_cmd_reg  : std_logic_vector(31 downto 0);

    -- Force Vivado to keep the boundary for the CPU instance intact
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of cpu_inst : label is "yes";
    attribute dont_touch : string;
    attribute dont_touch of s_oled_cmd_reg : signal is "true";
begin

    -- =========================================================================
    -- 1. RISC-V CPU / Processor Core Instantiation (rv32i_top)
    -- =========================================================================
    cpu_inst : entity work.rv32i_top
        port map (
            clock            => clock,
            reset            => reset,
            oled_cmd_reg_out => s_oled_cmd_reg
        );

    -- =========================================================================
    -- 2. OLED Controller Driver Instantiation
    -- =========================================================================
    oled_ctrl_inst : entity work.oled_controller
        port map (
            clk         => clock,
            rst         => reset,
            cmd_data    => s_oled_cmd_reg,
            oled_sdin   => oled_sdin,
            oled_sclk   => oled_sclk,
            oled_dc     => oled_dc,
            oled_res    => oled_res,
            oled_vbat   => oled_vbat,
            oled_vdd    => oled_vdd
        );

end architecture Behavioral;