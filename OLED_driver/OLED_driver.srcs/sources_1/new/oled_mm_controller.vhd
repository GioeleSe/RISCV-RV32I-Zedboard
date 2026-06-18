-- ============================================================================
-- RV32I Memory-Mapped OLED Controller (Word-Aligned Interface)
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oled_mm_controller is
    port (
        -- Global Clock and Reset
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Processor Bus Interface (Word-Aligned Sub-Signals)
        bus_addr    : in  std_logic_vector(7 downto 0);  -- Lower byte offsets
        bus_wdata   : in  std_logic_vector(31 downto 0); -- Full 32-bit Write Word
        bus_rdata   : out std_logic_vector(31 downto 0); -- Full 32-bit Read Word
        bus_we      : in  std_logic;                     -- Write strobe
        bus_re      : in  std_logic;                     -- Read strobe
        
        -- Physical OLED Hardware Lines
        oled_sdin   : out std_logic;
        oled_sclk   : out std_logic;
        oled_dc     : out std_logic;
        oled_res    : out std_logic;
        oled_vbat   : out std_logic;
        oled_vdd    : out std_logic
    );
end oled_mm_controller;

architecture behavioral of oled_mm_controller is

    -- ------------------------------------------------------------------------
    -- Sub-Component Framework
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

    component oled_mm_updater is
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            en          : in  std_logic;
            ram_addr    : out std_logic_vector(5 downto 0);
            ram_rdata   : in  std_logic_vector(7 downto 0);
            sdout       : out std_logic;
            oled_sclk   : out std_logic;
            oled_dc     : out std_logic;
            fin         : out std_logic
        );
    end component;

    -- ------------------------------------------------------------------------
    -- State Machine
    -- ------------------------------------------------------------------------
    type t_states is (OLED_IDLE, OLED_INIT, OLED_READY, OLED_REFRESH, OLED_DONE);
    signal current_state : t_states := OLED_IDLE;

    -- Interconnect Links
    signal init_en         : std_logic := '0';
    signal init_done       : std_logic;
    signal init_sdata      : std_logic;
    signal init_spi_clk    : std_logic;
    signal init_dc         : std_logic;

    signal updater_en      : std_logic := '0';
    signal updater_sdata   : std_logic;
    signal updater_spi_clk : std_logic;
    signal updater_dc      : std_logic;
    signal updater_done    : std_logic;

    -- ------------------------------------------------------------------------
    -- Storage Matrix & Control Flags
    -- ------------------------------------------------------------------------
    type t_display_ram is array (0 to 63) of std_logic_vector(7 downto 0);
    signal display_ram : t_display_ram := (others => x"20"); -- Default to Space ASCII
    
    signal reg_ctrl_refresh : std_logic := '0';
    signal reg_status_busy  : std_logic := '0';
    
    signal ram_read_addr    : std_logic_vector(5 downto 0);
    signal ram_read_data    : std_logic_vector(7 downto 0);

    -- Internal Address decoding index matching word layout
    signal ram_write_index  : integer range 0 to 63;

begin

    -- Word index calculation: shift right by 2 (ignore byte-lanes), then subtract 4 
    -- because our buffer space starts at 0x10 (0x10 >> 2 = 4).
    ram_write_index <= to_integer(unsigned(bus_addr(7 downto 2))) - 4;

    -- ------------------------------------------------------------------------
    -- Device Drivers Mapping
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

    Updater_Inst : oled_mm_updater
        port map (
            clk         => clk,
            rst         => rst,
            en          => updater_en,
            ram_addr    => ram_read_addr,
            ram_rdata   => ram_read_data,
            sdout       => updater_sdata,
            oled_sclk   => updater_spi_clk,
            oled_dc     => updater_dc,
            fin         => updater_done
        );

    -- ------------------------------------------------------------------------
    -- Synchronous CPU Interface Processing
    -- ------------------------------------------------------------------------
    p_bus_handler : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg_ctrl_refresh <= '0';
                bus_rdata        <= (others => '0');
            else
                -- Auto-clearing system pulse
                reg_ctrl_refresh <= '0';
                
                -- CPU Write Bus Transaction
                if bus_we = '1' then
                    if bus_addr(7 downto 2) = "000000" then     -- 0x00 Control
                        reg_ctrl_refresh <= bus_wdata(0);
                    elsif bus_addr(7 downto 2) >= "000100" and bus_addr(7 downto 2) <= "010011" then -- 0x10 to 0x10C
                        display_ram(ram_write_index) <= bus_wdata(7 downto 0);
                    end if;
                end if;
                
                -- CPU Read Bus Transaction
                if bus_re = '1' then
                    bus_rdata <= (others => '0'); -- Default clear unmapped lines
                    
                    if bus_addr(7 downto 2) = "000000" then     -- 0x00 Control Read
                        bus_rdata(0) <= reg_ctrl_refresh;
                    elsif bus_addr(7 downto 2) = "000001" then  -- 0x04 Status Read
                        bus_rdata(0) <= reg_status_busy;
                    elsif bus_addr(7 downto 2) >= "000100" and bus_addr(7 downto 2) <= "010011" then -- 0x10 to 0x10C
                        bus_rdata(7 downto 0) <= display_ram(ram_write_index);
                    end if;
                end if;
            end if;
        end if;
    end process p_bus_handler;

    -- Secondary port read linked continuously to the OLED refresh machine
    ram_read_data <= display_ram(to_integer(unsigned(ram_read_addr)));

    -- ------------------------------------------------------------------------
    -- Bus Multiplexers & Flags
    -- ------------------------------------------------------------------------
    oled_sdin <= init_sdata   when (current_state = OLED_INIT) else updater_sdata;
    oled_sclk <= init_spi_clk when (current_state = OLED_INIT) else updater_spi_clk;
    oled_dc   <= init_dc      when (current_state = OLED_INIT) else updater_dc;

    init_en         <= '1' when (current_state = OLED_INIT) else '0';
    updater_en      <= '1' when (current_state = OLED_REFRESH) else '0';
    reg_status_busy <= '0' when (current_state = OLED_READY) else '1';

    -- ------------------------------------------------------------------------
    -- Main Peripheral Executive State Machine
    -- ------------------------------------------------------------------------
    p_fsm : process (clk)
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
                            current_state <= OLED_READY;
                        end if;
                    
                    when OLED_READY =>
                        if reg_ctrl_refresh = '1' then
                            current_state <= OLED_REFRESH;
                        end if;
                    
                    when OLED_REFRESH =>
                        if updater_done = '1' then
                            current_state <= OLED_DONE;
                        end if;
                    
                    when OLED_DONE =>
                        current_state <= OLED_READY;
                    
                    when others =>
                        current_state <= OLED_IDLE;
                        
                end case;
            end if;
        end if;
    end process p_fsm;

end behavioral;