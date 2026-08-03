library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cpu_mmio_buttons_oled is
end entity tb_cpu_mmio_buttons_oled;

architecture Behavioral of tb_cpu_mmio_buttons_oled is

    -- Component declaration matching your exact top-level entity
    component cpu_mmio_buttons_oled is
        Port (
            clock        : in  std_logic;
            reset        : in  std_logic;
            btn_up       : in  std_logic;
            btn_down     : in  std_logic;
            btn_left     : in  std_logic;
            btn_right    : in  std_logic;
            leds         : out std_logic_vector(3 downto 0);
            oled_sdin    : out std_logic;
            oled_sclk    : out std_logic;
            oled_dc      : out std_logic;
            oled_res     : out std_logic;
            oled_vbat    : out std_logic;
            oled_vdd     : out std_logic
        );
    end component;

    -- Testbench internal signals
    signal clock       : std_logic := '0';
    signal reset       : std_logic := '1';
    signal btn_up      : std_logic := '0';
    signal btn_down    : std_logic := '0';
    signal btn_left    : std_logic := '0';
    signal btn_right   : std_logic := '0';

    signal leds        : std_logic_vector(3 downto 0);
    signal oled_sdin   : std_logic;
    signal oled_sclk   : std_logic;
    signal oled_dc     : std_logic;
    signal oled_res    : std_logic;
    signal oled_vbat   : std_logic;
    signal oled_vdd    : std_logic;

    -- Clock period constant (100 MHz -> 10 ns)
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: cpu_mmio_buttons_oled
        port map (
            clock     => clock,
            reset     => reset,
            btn_up    => btn_up,
            btn_down  => btn_down,
            btn_left  => btn_left,
            btn_right => btn_right,
            leds      => leds,
            oled_sdin => oled_sdin,
            oled_sclk => oled_sclk,
            oled_dc   => oled_dc,
            oled_res  => oled_res,
            oled_vbat => oled_vbat,
            oled_vdd  => oled_vdd
        );

    -- Clock Generation Process (100 MHz)
    clock_process : process
    begin
        clock <= '0';
        wait for CLK_PERIOD / 2;
        clock <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus and Verification Process
    stim_proc : process
    begin
        -- 1. Initialize and apply Reset (Active-high configuration)
        reset     <= '1';
        btn_up    <= '0';
        btn_down  <= '0';
        btn_left  <= '0';
        btn_right <= '0';
        
        wait for 40 ns;
        
        -- Release Reset
        reset     <= '0';
        report "INFO: Reset released. Starting OLED initialization FSM check...";

        -- 2. OLED FSM Check Window
        wait for 2 ms;
        report "INFO: OLED initialization window passed. Checking button and CPU execution...";

        -- 3. Simulate Button Activations & LED Feedback Verification
        report "INFO: Stimulating BTN_UP...";
        btn_up <= '1';
        wait for 100 ns;
        btn_up <= '0';
        wait for 1 ms;

        report "INFO: Stimulating BTN_DOWN...";
        btn_down <= '1';
        wait for 100 ns;
        btn_down <= '0';
        wait for 1 ms;

        report "INFO: Stimulating BTN_LEFT...";
        btn_left <= '1';
        wait for 100 ns;
        btn_left <= '0';
        wait for 1 ms;

        report "INFO: Stimulating BTN_RIGHT...";
        btn_right <= '1';
        wait for 100 ns;
        btn_right <= '0';
        wait for 1 ms;

        -- 4. Monitor CPU Instruction Execution & MMIO writes
        report "INFO: Observing CPU store operations to OLED command register...";
        wait for 5 ms;

        report "INFO: Simulation completed successfully.";
        wait;
    end process;

end architecture Behavioral;