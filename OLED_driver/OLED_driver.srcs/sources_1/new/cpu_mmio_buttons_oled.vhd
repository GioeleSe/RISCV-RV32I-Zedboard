library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity cpu_mmio_buttons_oled is
    Port (
        clock        : in  std_logic;
        reset        : in  std_logic;
        btn_up       : in  std_logic;
        btn_down     : in  std_logic;
        btn_left     : in  std_logic;
        btn_right    : in  std_logic;
        -- LED feedback port for debugging
        leds         : out std_logic_vector(3 downto 0);
        -- OLED physical outputs
        oled_sdin    : out std_logic;
        oled_sclk    : out std_logic;
        oled_dc      : out std_logic;
        oled_res     : out std_logic;
        oled_vbat    : out std_logic;
        oled_vdd     : out std_logic
    );
end entity cpu_mmio_buttons_oled;

architecture Behavioral of cpu_mmio_buttons_oled is

    -- Internal signals for MMIO and register communication
    signal s_oled_cmd_reg  : std_logic_vector(31 downto 0);

begin

    -- =========================================================================
    -- 1. Hardware LED Feedback Mapping (LD3 = Right, LD2 = Left, LD1 = Down, LD0 = Up)
    -- =========================================================================
    leds <= btn_right & btn_left & btn_down & btn_up;


    -- =========================================================================
    -- 3. RISC-V CPU / Processor Core Instantiation (rv32i_top)
    -- =========================================================================
    cpu_inst : entity work.rv32i_top
        port map (
            clock            => clock,
            reset            => reset,
            btn_up           => btn_up,
            btn_down         => btn_down,
            btn_left         => btn_left,
            btn_right        => btn_right,
            oled_cmd_reg_out    => s_oled_cmd_reg
        );

    -- =========================================================================
    -- 4. OLED Controller Driver Instantiation
    -- =========================================================================
    oled_ctrl_inst : entity work.oled_controller
        port map (
            clk         => clock,
            rst       => reset,
            cmd_data    => s_oled_cmd_reg,
            oled_sdin   => oled_sdin,
            oled_sclk   => oled_sclk,
            oled_dc     => oled_dc,
            oled_res    => oled_res,
            oled_vbat   => oled_vbat,
            oled_vdd    => oled_vdd
        );

end architecture Behavioral;