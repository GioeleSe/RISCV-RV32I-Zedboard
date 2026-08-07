library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oled_controller is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        cmd_data   : in  std_logic_vector(31 downto 0);
        oled_sdin  : out std_logic;
        oled_sclk  : out std_logic;
        oled_dc    : out std_logic;
        oled_res   : out std_logic;
        oled_vbat  : out std_logic;
        oled_vdd   : out std_logic
    );
end oled_controller;

architecture behavioral of oled_controller is

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

    type t_states is (OLED_IDLE, OLED_INIT, OLED_SETTLE, OLED_RUN, OLED_LOOP_RESET);
    signal current_state : t_states := OLED_IDLE;

    signal init_en       : std_logic := '0';
    signal init_done     : std_logic;
    signal init_sdata    : std_logic;
    signal init_spi_clk  : std_logic;
    signal init_dc       : std_logic;

    signal app_en        : std_logic := '0';
    signal app_sdata     : std_logic;
    signal app_spi_clk   : std_logic;
    signal app_dc        : std_logic;
    signal app_done      : std_logic;

    signal dot_x         : std_logic_vector(7 downto 0) := (others => '0');
    signal dot_y         : std_logic_vector(7 downto 0) := (others => '0');
    signal frame_divider : integer range 0 to 700 := 0;

begin
    
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

    oled_sdin <= init_sdata  when (current_state = OLED_INIT or current_state = OLED_SETTLE) else app_sdata;
    oled_sclk <= init_spi_clk when (current_state = OLED_INIT or current_state = OLED_SETTLE) else app_spi_clk;
    oled_dc   <= init_dc     when (current_state = OLED_INIT or current_state = OLED_SETTLE) else app_dc;

    init_en <= '1' when (current_state = OLED_INIT) else '0';

    p_state_machine : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= OLED_IDLE;
                frame_divider <= 0;
                app_en        <= '0';
            else
                case current_state is
                    
                    when OLED_IDLE =>
                        current_state <= OLED_INIT;
                        app_en        <= '0';
                    
                    when OLED_INIT =>
                        if init_done = '1' then
                            current_state <= OLED_SETTLE;
                        end if;

                    when OLED_SETTLE =>
                        dot_x         <= cmd_data(7 downto 0);
                        dot_y         <= cmd_data(15 downto 8);
                        current_state <= OLED_RUN;
                        app_en        <= '1'; -- Trigger first frame start
                    
                    when OLED_RUN =>
                        if app_done = '1' then
                            app_en        <= '0'; -- Drop enable low to reset app state
                            current_state <= OLED_LOOP_RESET;
                        end if;
                    
                    when OLED_LOOP_RESET =>
                        dot_x         <= cmd_data(7 downto 0);
                        dot_y         <= cmd_data(15 downto 8);
                        current_state <= OLED_RUN;
                        app_en        <= '1';
                    when others =>
                        current_state <= OLED_IDLE;
                        app_en        <= '0';
                        
                end case;
            end if;
        end if;
    end process p_state_machine;

end behavioral;