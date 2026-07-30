library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity MemoryAccess is
port (
    clock: in std_logic;
    reset: in std_logic;
    
    -- Physical button inputs
    btn_up    : in std_logic;
    btn_down  : in std_logic;
    btn_left  : in std_logic;
    btn_right : in std_logic;
    
    rs1_addr_in: in std_logic_vector(4 downto 0);
    rs1_value_in: in std_logic_vector(31 downto 0);
    rs2_addr_in: in std_logic_vector(4 downto 0);
    rs2_value_in: in std_logic_vector(31 downto 0); 
    rd_addr_in: in std_logic_vector(4 downto 0);
    rd_value_in: in std_logic_vector(31 downto 0);
    next_pc: in std_logic_vector(31 downto 0);

    usage_mem_in: in std_logic;
    mem_addr_in: in std_logic_vector(31 downto 0);
    MEM_OP_in: in MEM_OP_T;
    MEM_OP_SIZE_in: in MEM_OP_SIZE_T;
    OP_SIGN_in: in OP_SIGN_T;
    usage_writeback_in: in std_logic;

    rs1_addr_out: out std_logic_vector(4 downto 0);                
    rs1_value_out: out std_logic_vector(31 downto 0);
    rs2_addr_out: out std_logic_vector(4 downto 0);
    rs2_value_out: out std_logic_vector(31 downto 0);
    pipe_writeback_enable_out: out std_logic;                        
    pipe_writeback_addr_out: out std_logic_vector(4 downto 0);
    pipe_writeback_value_out: out std_logic_vector(31 downto 0)
);
end entity MemoryAccess;

architecture behaviour of MemoryAccess is
    signal bram : BRAM_T := (others => (others => '0'));

    -- Force Vivado to map this signal to physical Block RAM
    attribute ram_style : string;
    attribute ram_style of bram : signal is "block";

    signal s_pipe_writeback_value : std_logic_vector(31 downto 0);
    signal s_masked_data_out      : std_logic_vector(31 downto 0);
    
    constant ADDR_BTN_REG         : std_logic_vector(31 downto 0) := x"000F0000";
    constant ADDR_OLED_CMD        : std_logic_vector(31 downto 0) := x"000F0004";
    signal s_oled_cmd_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal s_btn_data             : std_logic_vector(31 downto 0);

begin

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
        variable v_word_addr        : integer;
        variable v_data_out         : std_logic_vector(31 downto 0); 
        variable v_masked_data_out  : std_logic_vector(31 downto 0);
        variable v_pipe_writeback_value : std_logic_vector(31 downto 0);
        variable w_data             : std_logic_vector(31 downto 0);
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
            v_masked_data_out := (others => '0');

            if usage_mem_in = '1' then
                -- MMIO space check
                if unsigned(mem_addr_in) >= 16#000F0000# then
                    case(MEM_OP_in) is
                        when OP_LOAD =>
                            case mem_addr_in is
                                when x"000F0000" => v_masked_data_out := s_btn_data;
                                when x"000F0004" => v_masked_data_out := s_oled_cmd_reg;
                                when others      => v_masked_data_out := (others => '0');
                            end case;
                        when OP_STORE =>
                            case mem_addr_in is
                                when x"000F0004" => s_oled_cmd_reg <= rs2_value_in;
                                when others      => null;
                            end case;
                        when others =>
                            null;
                    end case;

                else
                    -- Regular BRAM space (Word-aligned indexing)
                    v_word_addr := to_integer(unsigned(mem_addr_in(13 downto 2)));
                    w_data := bram(v_word_addr);

                    case(MEM_OP_in) is 
                        when OP_LOAD =>
                            v_data_out := w_data;

                            -- Extract byte/halfword based on lower address bits
                            case(MEM_OP_SIZE_in) is
                                when OP_SIZE_BYTE =>
                                    case mem_addr_in(1 downto 0) is
                                        when "00"   => 
                                            if OP_SIGN_in = OP_SIGNED then
                                                v_masked_data_out := std_logic_vector(resize(signed(v_data_out(7 downto 0)), 32));
                                            else
                                                v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(7 downto 0)), 32));
                                            end if;
                                        when "01"   => 
                                            if OP_SIGN_in = OP_SIGNED then
                                                v_masked_data_out := std_logic_vector(resize(signed(v_data_out(15 downto 8)), 32));
                                            else
                                                v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(15 downto 8)), 32));
                                            end if;
                                        when "10"   => 
                                            if OP_SIGN_in = OP_SIGNED then
                                                v_masked_data_out := std_logic_vector(resize(signed(v_data_out(23 downto 16)), 32));
                                            else
                                                v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(23 downto 16)), 32));
                                            end if;
                                        when "11"   => 
                                            if OP_SIGN_in = OP_SIGNED then
                                                v_masked_data_out := std_logic_vector(resize(signed(v_data_out(31 downto 24)), 32));
                                            else
                                                v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(31 downto 24)), 32));
                                            end if;
                                        when others => null;
                                    end case;

                                when OP_SIZE_HALFWORD =>
                                    if mem_addr_in(1) = '0' then
                                        if OP_SIGN_in = OP_SIGNED then
                                            v_masked_data_out := std_logic_vector(resize(signed(v_data_out(15 downto 0)), 32));
                                        else
                                            v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(15 downto 0)), 32));
                                        end if;
                                    else
                                        if OP_SIGN_in = OP_SIGNED then
                                            v_masked_data_out := std_logic_vector(resize(signed(v_data_out(31 downto 16)), 32));
                                        else
                                            v_masked_data_out := std_logic_vector(resize(unsigned(v_data_out(31 downto 16)), 32));
                                        end if;
                                    end if;

                                when OP_SIZE_WORD =>
                                    v_masked_data_out := v_data_out;

                                when others =>
                                    null;
                            end case;

                        when OP_STORE =>
                            case(MEM_OP_SIZE_in) is
                                when OP_SIZE_BYTE =>
                                    case mem_addr_in(1 downto 0) is
                                        when "00"   => w_data(7 downto 0)   := rs2_value_in(7 downto 0);
                                        when "01"   => w_data(15 downto 8)  := rs2_value_in(7 downto 0);
                                        when "10"   => w_data(23 downto 16) := rs2_value_in(7 downto 0);
                                        when "11"   => w_data(31 downto 24) := rs2_value_in(7 downto 0);
                                        when others => null;
                                    end case;
                                when OP_SIZE_HALFWORD =>
                                    if mem_addr_in(1) = '0' then
                                        w_data(15 downto 0) := rs2_value_in(15 downto 0);
                                    else
                                        w_data(31 downto 16) := rs2_value_in(15 downto 0);
                                    end if;
                                when OP_SIZE_WORD =>
                                    w_data := rs2_value_in;
                                when others =>
                                    null;
                            end case;
                            bram(v_word_addr) <= w_data;

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