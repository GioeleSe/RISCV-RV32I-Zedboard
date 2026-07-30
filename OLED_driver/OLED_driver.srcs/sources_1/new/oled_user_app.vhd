-- ============================================================================
-- OLED User Application: Dynamic coordinate-driven square renderer
-- ============================================================================
-- FIX: The previous version drove oled_sclk <= clk directly (raw, undivided
-- 100 MHz, no start/stop framing) and drove sdout <= pixel_byte(0) (only ever
-- the LSB of the computed byte, never actually shifted out). That bypassed
-- the oled_spi block that every other module in this design (oled_initializer,
-- oled_example) correctly uses, and never sent the SSD1306 page/column
-- address commands either. The result is garbage written into the display's
-- GDDRAM -- the "random noise" on screen.
--
-- This version instantiates oled_spi (same as oled_initializer/oled_example)
-- so every byte is properly shifted out MSB-first on a correctly divided,
-- correctly framed serial clock, and it sends the Set Page / Set Column
-- Address commands before each page's pixel data, exactly like the known-
-- good oled_example.vhd reference implementation.
-- ============================================================================

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

    -- ------------------------------------------------------------------------
    -- SPI shifter (same block used by oled_initializer / oled_example)
    -- ------------------------------------------------------------------------
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

    -- Frame refresh state machine
    type t_app_state is (
        APP_IDLE,
        ClearDC, SetPageCmd, PageNumCmd, ColLowCmd, ColHighCmd, SetDataMode,
        SendPixel, NextCol,
        APP_DONE,
        Transition1, Transition2, Transition5
    );
    signal state       : t_app_state := APP_IDLE;
    signal after_state : t_app_state := APP_IDLE;

    -- Screen traversal counters for 128x32 display (128 columns, 4 vertical pages of 8 bits)
    signal col_cnt  : integer range 0 to 127 := 0;
    signal page_cnt : integer range 0 to 3   := 0;

    -- Parsed coordinate integers
    signal box_x    : integer range 0 to 255;
    signal box_y    : integer range 0 to 255;

    signal pixel_byte : std_logic_vector(7 downto 0);

    -- SPI submodule interconnect
    signal temp_dc      : std_logic := '0';
    signal temp_fin     : std_logic := '0';
    signal temp_spi_en  : std_logic := '0';
    signal temp_sdata   : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_spi_fin : std_logic;

begin

    box_x <= to_integer(unsigned(dot_x));
    box_y <= to_integer(unsigned(dot_y));

    oled_dc <= temp_dc;
    fin     <= temp_fin;

    -- ------------------------------------------------------------------------
    -- SPI shifter instance: does all the real serial clocking/framing
    -- ------------------------------------------------------------------------
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

    -- ========================================================================
    -- Pixel Mapping Logic (4x4 Block Generation)
    -- ========================================================================
    -- The SSD1306 organizes data into 8-pixel vertical pages. This process 
    -- computes whether the current column and page intersect with the user's square.
    process(col_cnt, page_cnt, box_x, box_y)
        variable v_byte : std_logic_vector(7 downto 0);
        variable v_row  : integer;
    begin
        v_byte := (others => '0');

        -- Check if current column falls within the horizontal bounds of the square
        if (col_cnt >= box_x) and (col_cnt < box_x + 4) then
            for r in 0 to 3 loop
                v_row := box_y + r;
                -- Check if the row matches the vertical stripe of the active page
                if (v_row >= page_cnt * 8) and (v_row < (page_cnt + 1) * 8) then
                    v_byte(v_row mod 8) := '1';
                end if;
            end loop;
        end if;

        pixel_byte <= v_byte;
    end process;

    -- ========================================================================
    -- Frame Refresh Control FSM
    -- ========================================================================
    -- For each of the 4 pages: send the Set Page Address / Set Column Address
    -- command sequence (identical to oled_example.vhd), then stream 128 data
    -- bytes (one per column) through oled_spi.
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
            else
                case state is
                    when APP_IDLE =>
                        temp_fin <= '0';
                        if en = '1' then
                            page_cnt <= 0;
                            state    <= ClearDC;
                        end if;

                    -- ----------------------------------------------------------
                    -- Page/Column address command sequence (command mode)
                    -- ----------------------------------------------------------
                    when ClearDC =>
                        temp_dc <= '0';
                        state   <= SetPageCmd;

                    when SetPageCmd =>
                        temp_sdata  <= "00100010"; -- 0x22: Set Page Start Address
                        after_state <= PageNumCmd;
                        state       <= Transition1;

                    when PageNumCmd =>
                        temp_sdata  <= "000000" & std_logic_vector(to_unsigned(page_cnt, 2));
                        after_state <= ColLowCmd;
                        state       <= Transition1;

                    when ColLowCmd =>
                        temp_sdata  <= "00000000"; -- Column low nibble = 0
                        after_state <= ColHighCmd;
                        state       <= Transition1;

                    when ColHighCmd =>
                        temp_sdata  <= "00010000"; -- Column high nibble = 0
                        after_state <= SetDataMode;
                        state       <= Transition1;

                    when SetDataMode =>
                        temp_dc <= '1';            -- Switch to data mode
                        col_cnt <= 0;
                        state   <= SendPixel;

                    -- ----------------------------------------------------------
                    -- Pixel data streaming (data mode) - one byte per column
                    -- ----------------------------------------------------------
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
                        state    <= APP_IDLE; -- Loops continuously to update position live

                    -- ----------------------------------------------------------
                    -- Shared SPI handshake (identical pattern to oled_initializer)
                    -- ----------------------------------------------------------
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