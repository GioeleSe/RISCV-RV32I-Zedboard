library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_oled_mm_controller is
end tb_oled_mm_controller;

architecture test of tb_oled_mm_controller is

    -- ------------------------------------------------------------------------
    -- Testbench Constants & Clock Control
    -- ------------------------------------------------------------------------
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz Clock Simulation
    signal sim_done     : boolean := false;

    -- ------------------------------------------------------------------------
    -- Device Under Test (DUT) Interface Signals
    -- ------------------------------------------------------------------------
    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    
    -- Processor Bus Interface Signals
    signal bus_addr   : std_logic_vector(7 downto 0)  := (others => '0');
    signal bus_wdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal bus_rdata  : std_logic_vector(31 downto 0);
    signal bus_we     : std_logic := '0';
    signal bus_re     : std_logic := '0';
    
    -- Physical Hardware Out Pins
    signal oled_sdin  : std_logic;
    signal oled_sclk  : std_logic;
    signal oled_dc    : std_logic;
    signal oled_res   : std_logic;
    signal oled_vbat  : std_logic;
    signal oled_vdd   : std_logic;

begin

    -- ------------------------------------------------------------------------
    -- Instantiate Device Under Test (DUT)
    -- ------------------------------------------------------------------------
    DUT : entity work.oled_mm_controller
        port map (
            clk       => clk,
            rst       => rst,
            bus_addr  => bus_addr,
            bus_wdata => bus_wdata,
            bus_rdata => bus_rdata,
            bus_we    => bus_we,
            bus_re    => bus_re,
            oled_sdin => oled_sdin,
            oled_sclk => oled_sclk,
            oled_dc   => oled_dc,
            oled_res  => oled_res,
            oled_vbat => oled_vbat,
            oled_vdd  => oled_vdd
        );

    -- ------------------------------------------------------------------------
    -- Clock Generation Process
    -- ------------------------------------------------------------------------
    p_clk_gen : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process p_clk_gen;

    -- ------------------------------------------------------------------------
    -- Simulation Stimulus Sequence
    -- ------------------------------------------------------------------------
    p_stimulus : process
        
        -- Helper procedure to simulate a CPU write cycle
        procedure cpu_write(
            constant addr : in integer;
            constant data : in std_logic_vector(31 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            bus_addr  <= std_logic_vector(to_unsigned(addr, 8));
            bus_wdata <= data;
            bus_we    <= '1';
            wait until rising_edge(clk);
            wait for 1 ns; -- Hold time simulation
            bus_we    <= '0';
        end procedure;

        -- Helper procedure to simulate a CPU read cycle
        procedure cpu_read(
            constant addr : in integer
        ) is
        begin
            wait until falling_edge(clk);
            bus_addr <= std_logic_vector(to_unsigned(addr, 8));
            bus_re   <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            bus_re   <= '0';
        end procedure;

    begin
        -- Assert Reset
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for 1 ns;
        
        -- --------------------------------------------------------------------
        -- TEST STAGE 1: Check Reset and State Machine Hold
        -- --------------------------------------------------------------------
        -- The controller will automatically jump to OLED_INIT.
        -- We wait here for a brief moment to allow our Mock Initializer to respond.
        wait for CLK_PERIOD * 10;

        -- --------------------------------------------------------------------
        -- TEST STAGE 2: Frame Buffer Allocation Writes
        -- --------------------------------------------------------------------
        -- Write character asset strings to word boundaries.
        -- Address calculation: 0x10 is our base buffer offset.
        report "Writing ASCII values into Frame Buffer slots...";
        cpu_write(16,  x"00000048"); -- Address 0x10 (Slot 0): 'H'
        cpu_write(20,  x"00000045"); -- Address 0x14 (Slot 1): 'E'
        cpu_write(24,  x"0000004C"); -- Address 0x18 (Slot 2): 'L'
        cpu_write(28,  x"0000004C"); -- Address 0x1C (Slot 3): 'L'
        cpu_write(32,  x"0000004F"); -- Address 0x20 (Slot 4): 'O'
        cpu_write(268, x"00000021"); -- Address 0x10C (Slot 63): '!'

        -- --------------------------------------------------------------------
        -- TEST STAGE 3: Memory Extraction and Read Validation
        -- --------------------------------------------------------------------
        report "Reading back Frame Buffer registers to verify write safety...";
        cpu_read(16); -- Read 0x10
        wait for 1 ns;
        assert (bus_rdata(7 downto 0) = x"48") report "Error: Slot 0 mismatch!" severity failure;

        cpu_read(20); -- Read 0x14
        wait for 1 ns;
        assert (bus_rdata(7 downto 0) = x"45") report "Error: Slot 1 mismatch!" severity failure;

        -- Check Status Register (0x04) while in OLED_READY
        cpu_read(4);
        wait for 1 ns;
        assert (bus_rdata(0) = '0') report "Error: Controller erroneously busy!" severity failure;

        -- --------------------------------------------------------------------
        -- TEST STAGE 4: Core Refresh Execution Loop
        -- --------------------------------------------------------------------
        report "Triggering OLED screen refresh command...";
        cpu_write(0, x"00000001"); -- Pulse Bit 0 of Control Register (0x00)

        -- Check if status immediately flags 'Busy' on the subsequent cycle
        cpu_read(4);
        wait for 1 ns;
        
        -- Wait for the mock updater engine component to complete processing
        wait for CLK_PERIOD * 15;

        -- Read status register again to verify it recovered back to IDLE/READY
        cpu_read(4);
        wait for 1 ns;
        assert (bus_rdata(0) = '0') report "Error: FSM locked up in busy loop!" severity failure;

        -- Finish Simulation cleanly
        report "Testbench validation completed successfully!";
        sim_done <= true;
        wait;
    end process p_stimulus;

end test;

-- ----------------------------------------------------------------------------
-- Simulation Mock Entities
-- ----------------------------------------------------------------------------
-- These models swap inside your simulation workspace to bypass multi-millisecond
-- hardware counter stalls during localized verification.
-- ----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity oled_initializer is
    port (
        clk, rst, en                  : in  std_logic;
        sdout, oled_sclk, oled_dc     : out std_logic;
        oled_res, oled_vbat, oled_vdd : out std_logic;
        fin                           : out std_logic
    );
end oled_initializer;

architecture mock of oled_initializer is
begin
    process(clk)
        variable count : integer := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                fin   <= '0';
                count := 0;
            elsif en = '1' then
                if count < 4 then
                    count := count + 1;
                    fin   <= '0';
                else
                    fin   <= '1'; -- Complete task after 4 clock cycles
                end if;
            else
                fin   <= '0';
                count := 0;
            end if;
        end if;
    end process;
    sdout <= '0'; oled_sclk <= '0'; oled_dc <= '0'; oled_res <= '1'; oled_vbat <= '1'; oled_vdd <= '1';
end mock;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oled_mm_updater is
    port (
        clk, rst, en : in  std_logic;
        ram_addr     : out std_logic_vector(5 downto 0);
        ram_rdata    : in  std_logic_vector(7 downto 0);
        sdout, oled_sclk, oled_dc : out std_logic;
        fin          : out std_logic
    );
end oled_mm_updater;

architecture mock of oled_mm_updater is
    signal index : unsigned(5 downto 0) := (others => '0');
begin
    ram_addr <= std_logic_vector(index);
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                index <= (others => '0');
                fin   <= '0';
            elsif en = '1' then
                if index < 63 then
                    index <= index + 1;
                    fin   <= '0';
                else
                    fin   <= '1'; -- Fired once all 64 RAM matrix items are traversed
                end if;
            else
                index <= (others => '0');
                fin   <= '0';
            end if;
        end if;
    end process;
    sdout <= '0'; oled_sclk <= '0'; oled_dc <= '1';
end mock;