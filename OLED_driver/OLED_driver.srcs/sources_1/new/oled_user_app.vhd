library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oled_user_app is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        en        : in  std_logic;
        dot_x     : in  std_logic_vector(7 downto 0); -- From CPU MMIO X coordinate
        dot_y     : in  std_logic_vector(7 downto 0); -- From CPU MMIO Y coordinate
        sdout     : out std_logic;
        oled_sclk : out std_logic;
        oled_dc   : out std_logic;
        fin       : out std_logic
    );
end entity oled_user_app;

architecture behavioral of oled_user_app is

    component oled_spi is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            en        : in  std_logic;
            sdata     : in  std_logic_vector(7 downto 0);
            sdout     : out std_logic;
            oled_sclk : out std_logic;
            fin       : out std_logic
        );
    end component;

    type t_app_state is (
        APP_IDLE,
        ClearDC, SetPageCmd, ColLowCmd, ColHighCmd, SetDataMode,
        SendPixel, NextCol,
        APP_DONE,
        Transition1, Transition2, Transition5
    );
    signal state       : t_app_state := APP_IDLE;
    signal after_state : t_app_state := APP_IDLE;

    signal col_cnt  : integer range 0 to 127 := 0;
    signal page_cnt : integer range 0 to 3   := 0;

    signal box_x_raw : integer range 0 to 255;
    signal box_y_raw : integer range 0 to 255;

    constant c_box_size : integer := 4;
    constant c_x_max    : integer := 128 - c_box_size; -- 124
    constant c_y_max    : integer := 32  - c_box_size; -- 28

    signal box_x : integer range 0 to c_x_max := 0;
    signal box_y : integer range 0 to c_y_max := 0;

    signal pixel_byte : std_logic_vector(7 downto 0);

    -- New coordinates arrive continuously (one per animation frame from CPU);
    -- request a refresh any time they differ from what's currently drawn.
    signal refresh_req : std_logic := '0';

    signal temp_dc      : std_logic := '0';
    signal temp_fin     : std_logic := '0';
    signal temp_spi_en  : std_logic := '0';
    signal temp_sdata   : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_spi_fin : std_logic;

begin

    box_x_raw <= to_integer(unsigned(dot_x));
    box_y_raw <= to_integer(unsigned(dot_y));

    oled_dc <= temp_dc;
    fin     <= temp_fin;

    oled_spi_comp : oled_spi
        port map (
            clk       => clk,
            rst       => rst,
            en        => temp_spi_en,
            sdata     => temp_sdata,
            sdout     => sdout,
            oled_sclk => oled_sclk,
            fin       => temp_spi_fin
        );

    -- Combinational: is a redraw needed against the currently displayed box?
    process(box_x_raw, box_y_raw, box_x, box_y)
    begin
        if ((box_x_raw <= c_x_max) and (box_x /= box_x_raw)) or
           ((box_y_raw <= c_y_max) and (box_y /= box_y_raw)) then
            refresh_req <= '1';
        else
            refresh_req <= '0';
        end if;
    end process;

    process(col_cnt, page_cnt, box_x, box_y)
        variable v_byte : std_logic_vector(7 downto 0);
        variable v_row  : integer;
    begin
        v_byte := (others => '0');

        if (col_cnt >= box_x) and (col_cnt < box_x + 4) then
            for r in 0 to 3 loop
                v_row := box_y + r;
                if (v_row >= page_cnt * 8) and (v_row < (page_cnt + 1) * 8) then
                    v_byte(v_row mod 8) := '1';
                end if;
            end loop;
        end if;

        pixel_byte <= v_byte;
    end process;

    p_refresh : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= APP_IDLE;
                after_state <= APP_IDLE;
                col_cnt     <= 0;
                page_cnt    <= 0;
                temp_fin    <= '0';
                temp_dc     <= '0';
                temp_spi_en <= '0';
                box_x       <= 0;
                box_y       <= 0;
            else
                case state is
                    when APP_IDLE =>
                        temp_fin <= '0';
                        if en = '1' then
                            if box_x_raw > c_x_max then
                                box_x <= c_x_max;
                            else
                                box_x <= box_x_raw;
                            end if;

                            if box_y_raw > c_y_max then
                                box_y <= c_y_max;
                            else
                                box_y <= box_y_raw;
                            end if;

                            page_cnt <= 0;
                            state    <= ClearDC;
                        end if;

                    when ClearDC =>
                        temp_dc <= '0';
                        state   <= SetPageCmd;

                    when SetPageCmd =>
                        -- Page Addressing Mode (SSD1306 power-on default, never changed
                        -- by the initializer): "Set Page Start Address" is the single-byte
                        -- command 0xB0 | page, NOT the two-byte 0x22 (that command only
                        -- applies in Horizontal/Vertical addressing mode).
                        temp_sdata  <= "1011" & "0" & std_logic_vector(to_unsigned(page_cnt, 3));
                        after_state <= ColLowCmd;
                        state       <= Transition1;

                    when ColLowCmd =>
                        temp_sdata  <= "00000000";
                        after_state <= ColHighCmd;
                        state       <= Transition1;

                    when ColHighCmd =>
                        temp_sdata  <= "00010000";
                        after_state <= SetDataMode;
                        state       <= Transition1;

                    when SetDataMode =>
                        temp_dc <= '1';
                        col_cnt <= 0;
                        state   <= SendPixel;

                    when SendPixel =>
                        temp_sdata  <= pixel_byte;
                        after_state <= NextCol;
                        state       <= Transition1;

                    when NextCol =>
                        if col_cnt < 127 then
                            col_cnt <= col_cnt + 1;
                            state   <= SendPixel;
                        elsif page_cnt < 3 then
                            page_cnt <= page_cnt + 1;
                            state    <= ClearDC;
                        else
                            state <= APP_DONE;
                        end if;

                    when APP_DONE =>
                        temp_fin <= '1';
                        state    <= APP_IDLE;

                    when Transition1 =>
                        temp_spi_en <= '1';
                        state       <= Transition2;

                    when Transition2 =>
                        if temp_spi_fin = '1' then
                            state <= Transition5;
                        end if;

                    when Transition5 =>
                        temp_spi_en <= '0';
                        state       <= after_state;

                    when others =>
                        state <= APP_IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture behavioral;