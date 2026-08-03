-- ============================================================================
-- OLED Controller: Top-level MMIO-integrated controller for CPU-driven graphics
-- Updated with continuous frame refresh loop
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oled_controller is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        cmd_data   : in  std_logic_vector(31 downto 0); -- Connected to MMIO s_oled_cmd_reg
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

    component oled_user_app is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            en        : in  std_logic;
            dot_x     : in  std_logic_vector(7 downto 0);
            dot_y     : in  std_logic_vector(7 downto 0);
            sdout     : out std_logic;
            oled_sclk : out std_logic;
            oled_dc   : out std_logic;
            fin       : out std_logic
        );
    end component;

    -- ------------------------------------------------------------------------
    -- Type & State Machine Definitions
    -- ------------------------------------------------------------------------
    type t_states is (OLED_IDLE, OLED_INIT, OLED_RUN, OLED_LOOP_RESET);
    signal current_state : t_states := OLED_IDLE;

    -- ------------------------------------------------------------------------
    -- Internal Interconnect Signals
    -- ------------------------------------------------------------------------
    signal init_en       : std_logic := '0';
    signal init_done     : std_logic;
    signal init_sdata    : std_logic;
    signal init_spi_clk  : std_logic;
    signal init_dc       : std_logic;

    signal app_en        : std_logic := '0';
    signal app_en_int    : std_logic := '0';
    signal app_sdata     : std_logic;
    signal app_spi_clk   : std_logic;
    signal app_dc        : std_logic;
    signal app_done      : std_logic;

    signal dot_x         : std_logic_vector(7 downto 0);
    signal dot_y         : std_logic_vector(7 downto 0);

begin

    -- ------------------------------------------------------------------------
    -- CPU MMIO Command Mapping
    -- ------------------------------------------------------------------------
    dot_x <= cmd_data(7 downto 0);
    dot_y <= cmd_data(15 downto 8);
    
    -- ------------------------------------------------------------------------
    -- Component Instances
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

    User_App_Inst : oled_user_app
        port map (
            clk       => clk,
            rst       => rst,
            en        => app_en,
            dot_x     => dot_x,
            dot_y     => dot_y,
            sdout     => app_sdata,
            oled_sclk => app_spi_clk,
            oled_dc   => app_dc,
            fin       => app_done
        );

    -- ------------------------------------------------------------------------
    -- Data & Routing Multiplexers (Combinational)
    -- ------------------------------------------------------------------------
    oled_sdin <= init_sdata  when (current_state = OLED_INIT) else app_sdata;
    oled_sclk <= init_spi_clk when (current_state = OLED_INIT) else app_spi_clk;
    oled_dc   <= init_dc     when (current_state = OLED_INIT) else app_dc;

    -- Module Enable distribution
    init_en <= '1' when (current_state = OLED_INIT) else '0';
    app_en  <= app_en_int;

    -- Generate a clean restart pulse for the user app every time a frame finishes
    app_en_int <= '1' when (current_state = OLED_RUN) else '0';

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
                            current_state <= OLED_RUN;
                        end if;
                    
                    when OLED_RUN =>
                        if app_done = '1' then
                            current_state <= OLED_LOOP_RESET;
                        end if;
                        
                    when OLED_LOOP_RESET =>
                        current_state <= OLED_RUN;
                    
                    when others =>
                        current_state <= OLED_IDLE;
                        
                end case;
            end if;
        end if;
    end process p_state_machine;

end behavioral;