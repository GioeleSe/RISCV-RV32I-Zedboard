library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_controller is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        btn_up    : in  std_logic;
        btn_down  : in  std_logic;
        btn_left  : in  std_logic;
        btn_right : in  std_logic;
        btn_data  : out std_logic_vector(31 downto 0)
    );
end entity button_controller;

architecture behavioral of button_controller is
    -- Synchronizer flip-flops for metastability protection
    signal btn_up_sync0, btn_up_sync1       : std_logic := '0';
    signal btn_down_sync0, btn_down_sync1   : std_logic := '0';
    signal btn_left_sync0, btn_left_sync1   : std_logic := '0';
    signal btn_right_sync0, btn_right_sync1 : std_logic := '0';

    -- Debounce: counters that must saturate before a change is accepted.
    -- ~1ms @ 100 MHz. Increase if your buttons still bounce through this.
    constant c_debounce_max : unsigned(16 downto 0) := to_unsigned(100_000, 17);

    signal up_cnt, down_cnt, left_cnt, right_cnt : unsigned(16 downto 0) := (others => '0');
    signal btn_up_db, btn_down_db, btn_left_db, btn_right_db : std_logic := '0';

    -- Generic per-button debounce update
    procedure debounce(
        signal sync_in  : in  std_logic;
        signal cnt      : inout unsigned(16 downto 0);
        signal stable   : inout std_logic
    ) is
    begin
        if sync_in /= stable then
            if cnt = c_debounce_max then
                stable <= sync_in;
                cnt    <= (others => '0');
            else
                cnt <= cnt + 1;
            end if;
        else
            cnt <= (others => '0');
        end if;
    end procedure;

begin

    p_sync : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                btn_up_sync0    <= '0'; btn_up_sync1    <= '0';
                btn_down_sync0  <= '0'; btn_down_sync1  <= '0';
                btn_left_sync0  <= '0'; btn_left_sync1  <= '0';
                btn_right_sync0 <= '0'; btn_right_sync1 <= '0';
            else
                -- Stage 0
                btn_up_sync0    <= btn_up;
                btn_down_sync0  <= btn_down;
                btn_left_sync0  <= btn_left;
                btn_right_sync0 <= btn_right;
                -- Stage 1
                btn_up_sync1    <= btn_up_sync0;
                btn_down_sync1  <= btn_down_sync0;
                btn_left_sync1  <= btn_left_sync0;
                btn_right_sync1 <= btn_right_sync0;
            end if;
        end if;
    end process p_sync;

    p_debounce : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                up_cnt <= (others => '0'); btn_up_db    <= '0';
                down_cnt <= (others => '0'); btn_down_db  <= '0';
                left_cnt <= (others => '0'); btn_left_db  <= '0';
                right_cnt <= (others => '0'); btn_right_db <= '0';
            else
                debounce(btn_up_sync1,    up_cnt,    btn_up_db);
                debounce(btn_down_sync1,  down_cnt,  btn_down_db);
                debounce(btn_left_sync1,  left_cnt,  btn_left_db);
                debounce(btn_right_sync1, right_cnt, btn_right_db);
            end if;
        end if;
    end process p_debounce;

    -- Map debounced button inputs to bits [3:0] of the 32-bit word vector
    -- Bit 0: Up, Bit 1: Down, Bit 2: Left, Bit 3: Right
    btn_data <= (31 downto 4 => '0') &
            btn_right_db & btn_left_db &
            btn_down_db  & btn_up_db;

end architecture behavioral;