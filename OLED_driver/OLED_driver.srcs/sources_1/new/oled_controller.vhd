-- ============================================================================
-- OLED Controller: Top-level entity to control the onboard oled fsm
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oled_controller is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        oled_sdin  : out std_logic;
        oled_sclk  : out std_logic;
        oled_dc    : out std_logic;
        oled_res   : out std_logic;
        oled_vbat  : out std_logic;
        oled_vdd   : out std_logic
    );
end oled_controller;

architecture behavioral of oled_controller is

    -- ------------------------------------------------------------------------
    -- Component Declarations
    -- ------------------------------------------------------------------------
    component oled_initializer is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            en        : in  std_logic;
            sdout     : out std_logic;
            oled_sclk : out std_logic;
            oled_dc   : out std_logic;
            oled_res  : out std_logic;
            oled_vbat : out std_logic;
            oled_vdd  : out std_logic;
            fin       : out std_logic
        );
    end component;

    component oled_example is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            en        : in  std_logic;
            sdout     : out std_logic;
            oled_sclk : out std_logic;
            oled_dc   : out std_logic;
            fin       : out std_logic
        );
    end component;

    -- ------------------------------------------------------------------------
    -- Type & State Machine Definitions
    -- ------------------------------------------------------------------------
    type t_states is (OLED_IDLE, OLED_INIT, OLED_TEST, OLED_DONE);
    signal current_state : t_states := OLED_IDLE;

    -- ------------------------------------------------------------------------
    -- Internal Interconnect Signals
    -- ------------------------------------------------------------------------
    -- Initializer Block Signals
    signal init_en       : std_logic := '0';
    signal init_done     : std_logic;
    signal init_sdata    : std_logic;
    signal init_spi_clk  : std_logic;
    signal init_dc       : std_logic;

    -- Example Block Signals
    signal example_en      : std_logic := '0';
    signal example_sdata   : std_logic;
    signal example_spi_clk : std_logic;
    signal example_dc      : std_logic;
    signal example_done    : std_logic;

begin

    -- ------------------------------------------------------------------------
    -- Component Instances (Using Safe Named Association Mapping)
    -- ------------------------------------------------------------------------
    Initialize_Inst : oled_initializer
        port map (
            clk       => clk,
            rst       => rst,
            en        => init_en,
            sdout     => init_sdata,
            oled_sclk => init_spi_clk,
            oled_dc   => init_dc,
            oled_res  => oled_res,
            oled_vbat => oled_vbat,
            oled_vdd  => oled_vdd,
            fin       => init_done
        );

    Example_Inst : oled_example
        port map (
            clk       => clk,
            rst       => rst,
            en        => example_en,
            sdout     => example_sdata,
            oled_sclk => example_spi_clk,
            oled_dc   => example_dc,
            fin       => example_done
        );

    -- ------------------------------------------------------------------------
    -- Data & Routing Multiplexers (Combinational)
    -- ------------------------------------------------------------------------
    -- Output routing dependent on current controller state
    oled_sdin <= init_sdata   when (current_state = OLED_INIT) else example_sdata;
    oled_sclk <= init_spi_clk when (current_state = OLED_INIT) else example_spi_clk;
    oled_dc   <= init_dc      when (current_state = OLED_INIT) else example_dc;

    -- Module Enable distribution
    init_en    <= '1' when (current_state = OLED_INIT) else '0';
    example_en <= '1' when (current_state = OLED_TEST) else '0';

    -- ------------------------------------------------------------------------
    -- Sequential State Machine Process
    -- ------------------------------------------------------------------------
    p_state_machine : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= OLED_IDLE;
            else
                case current_state is
                    
                    when OLED_IDLE =>
                        current_state <= OLED_INIT;
                    
                    when OLED_INIT =>
                        if init_done = '1' then
                            current_state <= OLED_TEST;
                        end if;
                    
                    when OLED_TEST =>
                        if example_done = '1' then
                            current_state <= OLED_DONE;
                        end if;
                    
                    when OLED_DONE =>
                        current_state <= OLED_DONE; -- Maintain final state until external reset
                    
                    when others =>
                        current_state <= OLED_IDLE;
                        
                end case;
            end if;
        end if;
    end process p_state_machine;

end behavioral;