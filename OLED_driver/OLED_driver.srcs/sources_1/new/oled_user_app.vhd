-- ============================================================================
-- OLED User Application: Dynamic coordinate-driven square renderer
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

    -- Frame refresh state machine
    type t_app_state is (APP_IDLE, APP_REFRESH_FRAME, APP_DONE);
    signal state : t_app_state := APP_IDLE;

    -- Screen traversal counters for 128x32 display (128 columns, 4 vertical pages of 8 bits)
    signal col_cnt  : integer range 0 to 127 := 0;
    signal page_cnt : integer range 0 to 3   := 0;

    -- Parsed coordinate integers
    signal box_x    : integer range 0 to 255;
    signal box_y    : integer range 0 to 255;
    
    signal pixel_byte : std_logic_vector(7 downto 0);

begin

    box_x <= to_integer(unsigned(dot_x));
    box_y <= to_integer(unsigned(dot_y));

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
    p_refresh : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= APP_IDLE;
                col_cnt  <= 0;
                page_cnt <= 0;
                fin      <= '0';
            else
                case state is
                    when APP_IDLE =>
                        fin <= '0';
                        if en = '1' then
                            col_cnt  <= 0;
                            page_cnt <= 0;
                            state    <= APP_REFRESH_FRAME;
                        end if;

                    when APP_REFRESH_FRAME =>
                        -- Traverse across all 128 columns and 4 pages
                        if col_cnt < 127 then
                            col_cnt <= col_cnt + 1;
                        else
                            col_cnt <= 0;
                            if page_cnt < 3 then
                                page_cnt <= page_cnt + 1;
                            else
                                state <= APP_DONE;
                            end if;
                        end if;

                    when APP_DONE =>
                        fin   <= '1';
                        state <= APP_IDLE; -- Loops continuously to update position live

                    when others =>
                        state <= APP_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- Output Drive Signals
    oled_dc   <= '1';                     -- Data mode for frame pixel stream
    oled_sclk <= clk;                     -- Clock mapping
    sdout     <= pixel_byte(0);           -- Serial data output line

end architecture behavioral;