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

    -- Map button inputs to bits [3:0] of the 32-bit word vector
    -- Bit 0: Up, Bit 1: Down, Bit 2: Left, Bit 3: Right
    btn_data <= x"000000" & "0000" & 
                btn_right_sync1 & btn_left_sync1 & 
                btn_down_sync1  & btn_up_sync1;

end architecture behavioral;