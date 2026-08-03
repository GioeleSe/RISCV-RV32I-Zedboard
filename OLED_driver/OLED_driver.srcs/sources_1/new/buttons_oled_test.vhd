library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity system_top is
port (
    clock       : in  std_logic;
    reset       : in  std_logic;
    
    -- Physical button inputs
    btn_up      : in  std_logic;
    btn_down    : in  std_logic;
    btn_left    : in  std_logic;
    btn_right   : in  std_logic;
    
    -- Physical OLED outputs
    oled_sdin   : out std_logic;
    oled_sclk   : out std_logic;
    oled_dc     : out std_logic;
    oled_res    : out std_logic;
    oled_vbat   : out std_logic;
    oled_vdd    : out std_logic
);
end entity system_top;

architecture behavioral of system_top is

    -- Signals for button controller output
    -- Bit 0: Up, Bit 1: Down, Bit 2: Left, Bit 3: Right (see button_controller.vhd)
    signal s_btn_data       : std_logic_vector(31 downto 0);

    -- Signal to drive the oled_controller command data input
    signal s_oled_cmd_data  : std_logic_vector(31 downto 0) := (others => '0');

    -- ------------------------------------------------------------------------
    -- Persistent on-screen position of the 4x4 square.
    -- Display is 128 columns x 32 rows (4 pages of 8 rows) -> valid top-left
    -- corner range is x: 0..124, y: 0..28 so the 4x4 box stays fully on-screen.
    -- Starts centered: x = (128-4)/2 = 62, y = (32-4)/2 = 14.
    -- ------------------------------------------------------------------------
    constant c_box_size : integer := 4;
    constant c_x_max    : integer := 128 - c_box_size; -- 124
    constant c_y_max    : integer := 32  - c_box_size; -- 28
    constant c_x_center : integer := c_x_max / 2;       -- 62
    constant c_y_center : integer := c_y_max / 2;       -- 14

    signal s_pos_x : integer range 0 to c_x_max := c_x_center;
    signal s_pos_y : integer range 0 to c_y_max := c_y_center;

    -- Movement pacing: without this the position would step at 100 MHz and
    -- appear to teleport instantly to the edge of the screen the instant a
    -- button is held. This divides the clock down to a human-visible rate.
    constant c_move_period : integer := 2_000_000; -- ~20 ms @ 100 MHz -> 50 steps/sec
    signal s_move_counter  : integer range 0 to c_move_period - 1 := 0;
    signal s_move_tick     : std_logic := '0';

begin

    -- 1. Instantiate Button Controller
    Inst_ButtonCtrl : entity work.button_controller
    port map (
        clk       => clock,
        rst       => reset,
        btn_up    => btn_up,
        btn_down  => btn_down,
        btn_left  => btn_left,
        btn_right => btn_right,
        btn_data  => s_btn_data
    );

    -- 2. Instantiate OLED Controller (Matched to your exact entity ports)
    Inst_OledCtrl : entity work.oled_controller
    port map (
        clk       => clock,
        rst       => reset,
        cmd_data  => s_oled_cmd_data,
        oled_sdin => oled_sdin,
        oled_sclk => oled_sclk,
        oled_dc   => oled_dc,
        oled_res  => oled_res,
        oled_vbat => oled_vbat,
        oled_vdd  => oled_vdd
    );

    -- 3. Movement Rate Divider
    -- Produces a single-cycle tick at ~50 Hz so the square moves at a
    -- readable speed instead of jumping across the screen in one frame.
    p_move_tick : process(clock, reset)
    begin
        if reset = '1' then
            s_move_counter <= 0;
            s_move_tick    <= '0';
        elsif rising_edge(clock) then
            if s_move_counter = c_move_period - 1 then
                s_move_counter <= 0;
                s_move_tick    <= '1';
            else
                s_move_counter <= s_move_counter + 1;
                s_move_tick    <= '0';
            end if;
        end if;
    end process p_move_tick;

    -- 4. Position Accumulator
    -- Holds the square's position across frames (does NOT reset it from the
    -- button state every cycle). Starts centered, and on every move tick
    -- nudges the position one step in whichever direction is currently held,
    -- clamped so the box never runs off the visible screen. X and Y move
    -- independently so diagonal presses work too.
    p_position : process(clock, reset)
    begin
        if reset = '1' then
            s_pos_x <= c_x_center;
            s_pos_y <= c_y_center;
        elsif rising_edge(clock) then
            if s_move_tick = '1' then
                if s_btn_data(2) = '1' and s_pos_x > 0 then       -- Left
                    s_pos_x <= s_pos_x - 1;
                elsif s_btn_data(3) = '1' and s_pos_x < c_x_max then -- Right
                    s_pos_x <= s_pos_x + 1;
                end if;

                if s_btn_data(0) = '1' and s_pos_y > 0 then       -- Up
                    s_pos_y <= s_pos_y - 1;
                elsif s_btn_data(1) = '1' and s_pos_y < c_y_max then -- Down
                    s_pos_y <= s_pos_y + 1;
                end if;
            end if;
        end if;
    end process p_position;

    -- 5. Pack the persistent position into the 32-bit MMIO command word
    -- oled_controller extracts dot_x <= cmd_data(7:0), dot_y <= cmd_data(15:8)
    s_oled_cmd_data <= std_logic_vector(to_unsigned(0, 16)) &
                        std_logic_vector(to_unsigned(s_pos_y, 8)) &
                        std_logic_vector(to_unsigned(s_pos_x, 8));

end architecture behavioral;