library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.ALL;

entity InstructionExecution is
    port(
        clock: in std_logic;
        reset: in std_logic;

        next_pc: in std_logic_vector(31 downto 0);
        rs1_addr: in std_logic_vector(4 downto 0);
        rs1_value: in std_logic_vector(31 downto 0);
        rs2_addr: in std_logic_vector(4 downto 0);
        rs2_value: in std_logic_vector(31 downto 0);
        rd_addr: in std_logic_vector(4 downto 0);
        immediate: in std_logic_vector(31 downto 0);
        instruction_class: in INST_CLASS_T;
        ALU_OP: in ALU_OP_T;
        MEM_OP: in MEM_OP_T;
        MEM_OP_SIZE: in MEM_OP_SIZE_T;
        OP_SIGN: in OP_SIGN_T;
        usage_mem: in std_logic;
        usage_writeback: in std_logic;

        rs1_addr_out: out std_logic_vector(4 downto 0);
        rs1_value_out: out std_logic_vector(31 downto 0);
        rs2_addr_out: out std_logic_vector(4 downto 0);
        rs2_value_out: out std_logic_vector(31 downto 0);
        rd_addr_out: out std_logic_vector(4 downto 0);
        rd_value_out: out std_logic_vector(31 downto 0);
        reg_pc: out std_logic_vector(31 downto 0);
        mem_addr_out: out std_logic_vector(31 downto 0);
        MEM_OP_out: out MEM_OP_T;
        MEM_OP_SIZE_out: out MEM_OP_SIZE_T;
        OP_SIGN_out: out OP_SIGN_T;
        usage_mem_out: out std_logic;
        usage_writeback_out: out std_logic;
    );
end entity InstructionExecution;

architecture behaviour of InstructionExecution is
begin
    --  it needs to:
    --      recognize and check for any branch/jump operations [DONE]
    --      recognize and apply the ALU operation [DONE]
    --      define the memory address to be used for load/store operations [DONE]
    --      pass down the registers values [DONE]

    synchronousExecutionLogic: process(clock, reset)
        variable v_alu_result: std_logic_vector(31 downto 0);
        variable v_rs1_signed_value: signed(31 downto 0);
        variable v_rs1_unsigned_value: unsigned(31 downto 0);
        variable v_rs2_signed_value: signed(31 downto 0);
        variable v_rs2_unsigned_value: unsigned(31 downto 0);
        variable v_rd_value: std_logic_vector(31 downto 0);
        variable v_shift_amount: integer range 0 to 31;
        variable v_immediate_signed: signed(31 downto 0);
        variable v_immediate_unsigned: unsigned(31 downto 0);
    begin
        if reset = '1' then
            rs1_addr_out <= (others => '0');
            rs1_value_out <= (others => '0');
            rs2_addr_out <= (others => '0');
            rs2_value_out <= (others => '0');
            rd_addr_out <= (others => '0');
            v_rd_value := (others => '0');
            v_alu_result := (others => '0');
            mem_addr_out <= (others => '0');
            MEM_OP_out <= OP_LOAD;
            MEM_OP_SIZE_out <= OP_SIZE_WORD;
            OP_SIGN_out <= OP_UNSIGNED;
            usage_mem_out <= '0';
            usage_writeback_out <= '0';
        elsif rising_edge(clock) then
            rs1_addr_out <= rs1_addr;
            rs1_value_out <= rs1_value;
            rs2_addr_out <= rs2_addr;
            rs2_value_out <= rs2_value;
            rd_addr_out <= rd_addr;
            usage_mem_out <= usage_mem;
            MEM_OP_out <= MEM_OP;
            MEM_OP_SIZE_out <= MEM_OP_SIZE;
            OP_SIGN_out <= OP_SIGN;
            usage_writeback_out <= usage_writeback;

            v_rs1_signed_value := signed(rs1_value);
            v_rs1_unsigned_value := unsigned(rs1_value);
            v_rs2_signed_value := signed(rs2_value);
            v_rs2_unsigned_value := unsigned(rs2_value);
            v_immediate_signed := signed(immediate);
            v_immediate_unsigned := unsigned(immediate);

            if instruction_class = INST_CLASS_I or instruction_class = INST_CLASS_U then
                v_rs2_signed_value := v_immediate_signed;
                v_rs2_unsigned_value := v_immediate_unsigned;
            end if;
            
            v_shift_amount := to_integer(v_rs2_unsigned_value(4 downto 0));
                            
            case ALU_OP is
                when OP_ADD =>
                    case OP_SIGN is
                        when OP_SIGNED =>
                            v_alu_result := std_logic_vector(v_rs1_signed_value + v_rs2_signed_value);
                        when others =>
                            v_alu_result := std_logic_vector(v_rs1_unsigned_value + v_rs2_unsigned_value);
                    end case;
                when OP_SUB => 
                    case OP_SIGN is
                        when OP_SIGNED =>
                            v_alu_result := std_logic_vector(v_rs1_signed_value - v_rs2_signed_value);
                        when others =>
                            v_alu_result := std_logic_vector(v_rs1_unsigned_value - v_rs2_unsigned_value);
                    end case;
                when OP_AND => 
                    v_alu_result := std_logic_vector(v_rs1_unsigned_value and v_rs2_unsigned_value);
                when OP_OR => 
                    v_alu_result := std_logic_vector(v_rs1_unsigned_value or v_rs2_unsigned_value);
                when OP_XOR => 
                    v_alu_result := std_logic_vector(v_rs1_unsigned_value xor v_rs2_unsigned_value);
                when OP_SLL => 
                    v_alu_result := std_logic_vector(v_rs1_unsigned_value sll v_shift_amount);
                when OP_SRL => 
                    v_alu_result := std_logic_vector(v_rs1_unsigned_value srl v_shift_amount);
                when OP_SRA => 
                    v_alu_result := std_logic_vector(v_rs1_signed_value sra v_shift_amount);
                when OP_SLT =>
                    case OP_SIGN is
                        when OP_SIGNED =>
                            if (v_rs1_signed_value < v_rs2_signed_value) then
                                v_alu_result := x"00000001";
                            else
                                v_alu_result := (others => '0');
                            end if;                                
                        when others =>
                            if (v_rs1_unsigned_value < v_rs2_unsigned_value) then
                                v_alu_result := x"00000001";
                            else
                                v_alu_result := (others => '0');
                            end if;
                    end case;
                when OP_LUI => 
                    v_alu_result := std_logic_vector((v_rs2_unsigned_value sll 12));
                when OP_AUIPC => 
                    v_alu_result := AdderFunction(UNSIGNED_UNSIGNED, std_logic_vector(unsigned(next_pc) - 4), std_logic_vector(v_rs2_unsigned_value sll 12));
                when OP_MEM =>
                    v_alu_result := AdderFunction(UNSIGNED_SIGNED, std_logic_vector(v_rs1_unsigned_value), std_logic_vector(v_immediate_signed));
                    mem_addr_out <= v_alu_result;
                when OP_JAL | OP_JALR =>
                    -- store the next_pc in rd (op_jal has usage_writeback:='0' to prevent corruption)
                    v_alu_result := next_pc;
                when OP_BR =>
                    null;
                when OP_NOP =>
                    null;
                when others => 
                    v_alu_result := (others => '0');
            end case;
            v_rd_value := v_alu_result;

        end if;
        reg_pc <= next_pc;
        rd_value_out <= v_rd_value;
    end process;

end behaviour;