library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity MemoryAccess is
port (
    clock: in std_logic;
    reset: in std_logic;
    
    -- Physical button inputs added to entity interface
    btn_up    : in std_logic;
    btn_down  : in std_logic;
    btn_left  : in std_logic;
    btn_right : in std_logic;
    
    rs1_addr_in: in std_logic_vector(4 downto 0);
    rs1_value_in: in std_logic_vector(31 downto 0);
    rs2_addr_in: in std_logic_vector(4 downto 0);
    rs2_value_in: in std_logic_vector(31 downto 0);                    -- the value to store (s[w|h|b] rs2, off(rs1))
    rd_addr_in: in std_logic_vector(4 downto 0);
    rd_value_in: in std_logic_vector(31 downto 0);
    next_pc: in std_logic_vector(31 downto 0);

    usage_mem_in: in std_logic;
    mem_addr_in: in std_logic_vector(31 downto 0);
    MEM_OP_in: in MEM_OP_T;
    MEM_OP_SIZE_in: in MEM_OP_SIZE_T;
    OP_SIGN_in: in OP_SIGN_T;
    usage_writeback_in: in std_logic;

    rs1_addr_out: out std_logic_vector(4 downto 0);                    -- might be used for pipeline control
    rs1_value_out: out std_logic_vector(31 downto 0);
    rs2_addr_out: out std_logic_vector(4 downto 0);
    rs2_value_out: out std_logic_vector(31 downto 0);
    pipe_writeback_enable_out: out std_logic;                        -- writeback as final step of instructions execution
    pipe_writeback_addr_out: out std_logic_vector(4 downto 0);
    pipe_writeback_value_out: out std_logic_vector(31 downto 0)
);
end entity MemoryAccess;

architecture behaviour of MemoryAccess is
    signal bram : BRAM_T := (others => (others => '0'));

    signal s_data_out: std_logic_vector(31 downto 0);
    signal s_masked_data_out: std_logic_vector(31 downto 0);
    signal s_pipe_writeback_value: std_logic_vector(31 downto 0);
    signal s_pipe_async_data_out: std_logic_vector(31 downto 0);
    
    constant ADDR_BTN_REG   : std_logic_vector(31 downto 0) := x"000F0000";
    constant ADDR_OLED_CMD  : std_logic_vector(31 downto 0) := x"000F0004";
    signal s_mmio_read_data : std_logic_vector(31 downto 0);
    signal s_oled_cmd_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal s_btn_data       : std_logic_vector(31 downto 0);
begin
    -- Fixed component instantiation syntax and mappings
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

    memoryAccessControl: process(clock, reset)
        variable v_word_addr: integer;
        variable v_data_out: std_logic_vector(31 downto 0); 
        variable v_masked_data_out: std_logic_vector(31 downto 0);
        variable v_pipe_writeback_value: std_logic_vector(31 downto 0);
    begin
        if reset = '1' then
            s_pipe_writeback_value <= (others => '0');
            s_oled_cmd_reg <= (others => '0');
            rs1_addr_out <= (others => '0');
            rs1_value_out <= (others => '0');
            rs2_addr_out <= (others => '0');
            rs2_value_out <= (others => '0');
            pipe_writeback_enable_out <= '0';
            pipe_writeback_addr_out <= (others => '0');
            pipe_writeback_value_out <= (others => '0');
        elsif rising_edge(clock) then
            v_word_addr := to_integer(unsigned(mem_addr_in));
            v_masked_data_out := (others => '0');

            if usage_mem_in = '1' then
                -- MMIO space
                if v_word_addr >= 16#000F0000# then
                    case(MEM_OP_in) is
                        when OP_LOAD =>
                            case v_word_addr is
                                when 16#000F0000# => v_masked_data_out := s_btn_data;
                                when 16#000F0004# => v_masked_data_out := s_oled_cmd_reg;
                                when others       => v_masked_data_out := (others => '0');
                            end case;
                        when OP_STORE =>
                            case v_word_addr is
                                when 16#000F0004# => s_oled_cmd_reg <= rs2_value_in;
                                when others       => null;
                            end case;
                        when others =>
                            null;
                    end case;

                elsif v_word_addr <= 614399 then
                    -- regular BRAM space
                    case(MEM_OP_in) is 
                        when OP_LOAD =>
                            v_data_out := bram(v_word_addr + 3) & bram(v_word_addr + 2) & bram(v_word_addr + 1) & bram(v_word_addr);

                            case(MEM_OP_SIZE_in) is
                                when OP_SIZE_BYTE =>
                                    if OP_SIGN_in = OP_SIGNED then
                                        v_masked_data_out := std_logic_vector(resize(signed(v_data_out(7 downto 0)), 32));
                                    else
                                        v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(7 downto 0)), 32));
                                    end if;
                                when OP_SIZE_HALFWORD =>
                                    if OP_SIGN_in = OP_SIGNED then
                                        v_masked_data_out := std_logic_vector(resize(signed(v_data_out(15 downto 0)), 32));
                                    else
                                        v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(15 downto 0)), 32));
                                    end if;
                                when OP_SIZE_WORD =>
                                    v_masked_data_out := v_data_out;
                                when others =>
                                    null;
                            end case;

                        when OP_STORE =>
                            case(MEM_OP_SIZE_in) is
                                when OP_SIZE_BYTE =>
                                    bram(v_word_addr) <= rs2_value_in(7 downto 0);
                                when OP_SIZE_HALFWORD =>
                                    bram(v_word_addr)   <= rs2_value_in(7 downto 0);
                                    bram(v_word_addr+1) <= rs2_value_in(15 downto 8);
                                when OP_SIZE_WORD =>
                                    bram(v_word_addr)   <= rs2_value_in(7 downto 0);
                                    bram(v_word_addr+1) <= rs2_value_in(15 downto 8);
                                    bram(v_word_addr+2) <= rs2_value_in(23 downto 16);
                                    bram(v_word_addr+3) <= rs2_value_in(31 downto 24);
                                when others =>
                                    null;
                            end case;
                        when others =>
                            null;
                    end case;
                end if;
            end if;

            v_pipe_writeback_value := rd_value_in;
            if (usage_mem_in = '1') and (MEM_OP_in = OP_LOAD) then
                v_pipe_writeback_value := v_masked_data_out;
            end if;
            
            rs1_addr_out <= rs1_addr_in;
            rs1_value_out <= rs1_value_in;
            rs2_addr_out <= rs2_addr_in;
            rs2_value_out <= rs2_value_in;
            pipe_writeback_enable_out <= usage_writeback_in;
            pipe_writeback_addr_out <= rd_addr_in;
            pipe_writeback_value_out <= v_pipe_writeback_value;
        end if;
    end process;
end behaviour;