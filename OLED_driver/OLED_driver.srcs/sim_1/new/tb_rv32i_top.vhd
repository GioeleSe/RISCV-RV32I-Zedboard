library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_rv32i_top is
end entity tb_rv32i_top;

architecture Behavioral of tb_rv32i_top is

    -- Component declaration matching your exact rv32i_top entity
    component rv32i_top is
        port (
            clock               : in std_logic;
            reset               : in std_logic;
            btn_up              : in std_logic := '0';
            btn_down            : in std_logic := '0';
            btn_left            : in std_logic := '0';
            btn_right           : in std_logic := '0';
            oled_cmd_reg_out    : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Testbench internal signals
    signal clock            : std_logic := '0';
    signal reset            : std_logic := '1';
    signal btn_up           : std_logic := '0';
    signal btn_down         : std_logic := '0';
    signal btn_left         : std_logic := '0';
    signal btn_right        : std_logic := '0';
    signal oled_cmd_reg_out : std_logic_vector(31 downto 0);

    -- Clock period constant (100 MHz -> 10 ns)
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: rv32i_top
        port map (
            clock               => clock,
            reset               => reset,
            btn_up              => btn_up,
            btn_down            => btn_down,
            btn_left            => btn_left,
            btn_right           => btn_right,
            oled_cmd_reg_out    => oled_cmd_reg_out
        );

    -- Clock generation process (100 MHz)
    clock_process : process
    begin
        clock <= '0';
        wait for CLK_PERIOD / 2;
        clock <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus and Debug Verification Process (Sequential Single-Button Testing)
    stim_process : process
    begin
        -- 1. Initialize and assert reset
        reset     <= '1';
        btn_up    <= '0';
        btn_down  <= '0';
        btn_left  <= '0';
        btn_right <= '0';
        wait for 40 ns;
        
        -- Release reset
        reset <= '0';
        report "=== Simulation Started: Reset Released ===";

        -- 2. Allow processor to run through initialization (Indices 0 to 18)
        -- Initial X position = 64 (0x40), Initial Y position = 14 (0x0E)
        -- Initial oled_cmd_reg_out target: 0x00000E40
        wait for 250 * CLK_PERIOD;
        report "=== Checkpoint 1: Initialization complete. X = 64, Y = 14 ===";

        -- 3. Test Action 1: Press UP alone
        report "=== Applying Stimulus: Pressing UP ===";
        btn_up <= '1';
        wait for 110_000 * CLK_PERIOD; -- Wait for debouncer saturation + loop cycles
        btn_up <= '0';                  -- Release button
        wait for 10_000 * CLK_PERIOD;

        -- 4. Test Action 2: Press DOWN alone
        report "=== Applying Stimulus: Pressing DOWN ===";
        btn_down <= '1';
        wait for 110_000 * CLK_PERIOD;
        btn_down <= '0';
        wait for 10_000 * CLK_PERIOD;

        -- 5. Test Action 3: Press RIGHT alone
        report "=== Applying Stimulus: Pressing RIGHT ===";
        btn_right <= '1';
        wait for 110_000 * CLK_PERIOD;
        btn_right <= '0';
        wait for 10_000 * CLK_PERIOD;

        -- 6. Test Action 4: Press LEFT alone
        report "=== Applying Stimulus: Pressing LEFT ===";
        btn_left <= '1';
        wait for 110_000 * CLK_PERIOD;
        btn_left <= '0';
        wait for 10_000 * CLK_PERIOD;

        report "=== Simulation Successfully Completed ===";
        wait;
    end process;

end architecture Behavioral;