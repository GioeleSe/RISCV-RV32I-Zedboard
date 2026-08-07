library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity InstructionDecoder is
    port(
        clock: in std_logic;                                        -- mapped directly to the register file (memory)
        reset: in std_logic;

        curr_instruction: in std_logic_vector(31 downto 0);
        next_pc: in std_logic_vector(31 downto 0);
        branch_prediction: in std_logic;

        pipe_writeback_enable: in std_logic;                        -- register file, write access from next stages result
        pipe_writeback_addr: in std_logic_vector(4 downto 0);
        pipe_writeback_value: in std_logic_vector(31 downto 0);
        
        rs1_addr: out std_logic_vector(4 downto 0);
        rs1_value: out std_logic_vector(31 downto 0);
        rs2_addr: out std_logic_vector(4 downto 0);
        rs2_value: out std_logic_vector(31 downto 0);
        rd_addr: out std_logic_vector(4 downto 0);
        immediate: out std_logic_vector(31 downto 0);

        instruction_class: out INST_CLASS_T;
        ALU_OP: out ALU_OP_T;
        MEM_OP: out MEM_OP_T;
        MEM_OP_SIZE: out MEM_OP_SIZE_T;
        OP_SIGN: out OP_SIGN_T;

        jump_jalr_value: out std_logic_vector(31 downto 0);         -- JALR are executed here to reduce the pipe bubbles
        branch_misprediction: out std_logic;
        branch_offset: out std_logic_vector(31 downto 0);

        usage_mem: out std_logic;
        usage_writeback: out std_logic;
        reg_pc: out std_logic_vector(31 downto 0);
        regs_dump: out REG_MEMORY_T
    );
end entity InstructionDecoder;
architecture behaviour of InstructionDecoder is    
    signal s_rs1_addr: std_logic_vector(4 downto 0) := (others => '0');
    signal s_rs1_value: std_logic_vector(31 downto 0);
    signal s_rs2_addr: std_logic_vector(4 downto 0) := (others => '0');
    signal s_rs2_value: std_logic_vector(31 downto 0);
    signal s_rd_addr: std_logic_vector(4 downto 0) := (others => '0');
    signal s_immediate: std_logic_vector(31 downto 0);
    
    signal s_instruction_class: INST_CLASS_T := INST_CLASS_NOP;
    signal s_ALU_OP: ALU_OP_T := OP_NOP;
    signal s_MEM_OP: MEM_OP_T := OP_LOAD;
    signal s_MEM_OP_SIZE: MEM_OP_SIZE_T := OP_SIZE_WORD;
    signal s_OP_SIGN: OP_SIGN_T := OP_UNSIGNED;
    signal s_jump_jalr_value: std_logic_vector(31 downto 0);
    signal s_branch_misprediction: std_logic;
    signal s_branch_offset: std_logic_vector(31 downto 0);
    signal s_squash_next : std_logic := '0';                        -- mark next decoded instruction as wrong-path

    signal s_usage_mem: std_logic := '0';
    signal s_usage_writeback: std_logic := '0';

    signal s_mem_in_rs1_addr: std_logic_vector(4 downto 0) := (others => '0');
    signal s_mem_out_rs1_value: std_logic_vector(31 downto 0);
    signal s_mem_in_rs2_addr: std_logic_vector(4 downto 0) := (others => '0');
    signal s_mem_out_rs2_value: std_logic_vector(31 downto 0);
    signal s_mem_in_rd_addr: std_logic_vector(4 downto 0) := (others => '0');
    signal s_mem_in_rd_value: std_logic_vector(31 downto 0);
    signal s_mem_in_read_enable: std_logic := '0';
    signal s_mem_in_write_enable: std_logic := '0';
   component RegisterFile is
    port(
        clock: in std_logic;
        reset: in std_logic;
        addr_A: in std_logic_vector(4 downto 0);
        addr_B: in std_logic_vector(4 downto 0);
        read_enable: in std_logic;
        addr_C: in std_logic_vector(4 downto 0);
        write_C: in std_logic_vector(31 downto 0);
        write_enable: in std_logic;
        val_A: out std_logic_vector(31 downto 0);
        val_B: out std_logic_vector(31 downto 0);
        regs: out REG_MEMORY_T;
    );
    end component;
begin
    RegisterFileInstance: RegisterFile
    port map(
        clock => clock,
        reset => reset,
        addr_A => s_mem_in_rs1_addr,
        addr_B => s_mem_in_rs2_addr,
        read_enable => s_mem_in_read_enable,
        addr_C => s_mem_in_rd_addr,
        write_C => s_mem_in_rd_value,
        write_enable => s_mem_in_write_enable,
        val_A => s_mem_out_rs1_value,
        val_B => s_mem_out_rs2_value,
        regs => regs_dump
    );

    decodeInstruction:process(curr_instruction, s_mem_out_rs1_value, s_mem_out_rs2_value, branch_prediction)
        variable v_opcode: std_logic_vector(6 downto 0);      
        variable v_funct3: std_logic_vector(2 downto 0) := (others => '0');
        variable v_funct7: std_logic_vector(6 downto 0) := (others => '0');
        variable v_rd_addr: std_logic_vector(4 downto 0) := (others => '0');
        variable v_rs1_addr: std_logic_vector(4 downto 0) := (others => '0');
        variable v_rs2_addr: std_logic_vector(4 downto 0) := (others => '0');
        variable v_rd_value: std_logic_vector(31 downto 0) := (others => '0');
        variable v_immediate: std_logic_vector(31 downto 0) := (others => '0');
        variable v_immediate_12bits: std_logic_vector(11 downto 0) := (others => '0');
        variable v_immediate_13bits: std_logic_vector(12 downto 0) := (others => '0');
        variable v_immediate_21bits: std_logic_vector(20 downto 0) := (others => '0');
        variable v_rs1_value: std_logic_vector(31 downto 0) := (others => '0');
        variable v_rs2_value: std_logic_vector(31 downto 0) := (others => '0');
        variable v_rs1_value_unsigned: unsigned(31 downto 0) := (others => '0');
        variable v_rs2_value_unsigned: unsigned(31 downto 0) := (others => '0');
        variable v_rs1_value_signed: signed(31 downto 0) := (others => '0');
        variable v_rs2_value_signed: signed(31 downto 0) := (others => '0');

        variable v_instruction_class: INST_CLASS_T := INST_CLASS_NOP;
        variable v_ALU_OP: ALU_OP_T := OP_NOP;        -- OP_ADD, OP_SUB, ...  (use INST_CLASS=INST_CLASS_I to check addi, subi, ...)
        variable v_MEM_OP: MEM_OP_T := OP_LOAD;        -- OP_LOAD, OP_STORE
        variable v_MEM_OP_SIZE: MEM_OP_SIZE_T := OP_SIZE_WORD; -- OP_SIZE_BYTE, OP_SIZE_HALFWORD, OP_SIZE_WORD
        variable v_OP_SIGN: OP_SIGN_T := OP_UNSIGNED;      -- OP_SIGNED, OP_UNSIGNED (to get lbu, lhu, sltu, ...)
        variable v_BRANCH_OP_COND: BRANCH_OP_COND_T := OP_BRANCH_NE;
        variable v_jump_jalr_value: std_logic_vector(31 downto 0)  := (others => '0');
        variable v_branch_taken: std_logic := '0';
        variable v_branch_misprediction: std_logic := '0';
        variable v_branch_offset: std_logic_vector(31 downto 0) := (others => '0');
        
        variable v_usage_mem: std_logic := '0';
        variable v_usage_writeback: std_logic := '0';
    begin
        -- it needs to:
        --      recognize the instruction class [DONE]
        --      assign the new aluop type [DONE]
        --      set stages usage (mem_access, alu_usage, write_back) [DONE]
        --      immediate mapping [DONE]
        --      fetch rs1 and rs2 from memory [DONE]
        --      write back rd value [DONE]
        --      map output values [DONE]

        v_rd_addr      := (others => '0');                          -- pre-map static values (same position in different instruction classes)
        v_rs1_addr     := (others => '0');                          -- they are overwritten according to the instruction type
        v_rs2_addr     := (others => '0');
        v_funct3       := (others => '0');
        v_funct7       := (others => '0');
        v_immediate    := (others => '0');
        v_branch_misprediction := '0';
        
        v_opcode := curr_instruction(6 downto 0);
        v_instruction_class := INST_CLASS_ERR;
        v_usage_writeback := '1';
        v_usage_mem := '0';
        v_OP_SIGN := OP_SIGNED;

        case(v_opcode) is                       -- instruction class definition
            when "0110011" =>
                v_instruction_class := INST_CLASS_R;
            when "0010011" | "0000011" | "1110011" | "1100111"=> 
                v_instruction_class := INST_CLASS_I;
            when "0100011" =>
                v_instruction_class := INST_CLASS_S;
            when "1100011" =>
                v_instruction_class := INST_CLASS_B;
            when "1101111" =>
                v_instruction_class := INST_CLASS_J;
            when "0110111" | "0010111" =>
                v_instruction_class := INST_CLASS_U;
            when "0000000" =>
                v_instruction_class := INST_CLASS_NOP;
            when others =>
                v_instruction_class := INST_CLASS_ERR;
        end case;
        
        case v_instruction_class is
            when INST_CLASS_R =>
                v_rd_addr  := curr_instruction(11 downto 7);
                v_rs1_addr := curr_instruction(19 downto 15);
                v_rs2_addr := curr_instruction(24 downto 20);
                v_funct3   := curr_instruction(14 downto 12);
                v_funct7   := curr_instruction(31 downto 25);
        
            when INST_CLASS_I =>
                v_rd_addr  := curr_instruction(11 downto 7);
                v_rs1_addr := curr_instruction(19 downto 15);
                v_funct3   := curr_instruction(14 downto 12);
        
            when INST_CLASS_S =>
                v_rs1_addr := curr_instruction(19 downto 15);
                v_rs2_addr := curr_instruction(24 downto 20);
                v_funct3   := curr_instruction(14 downto 12);
        
            when INST_CLASS_B =>
                v_rs1_addr := curr_instruction(19 downto 15);
                v_rs2_addr := curr_instruction(24 downto 20);
                v_funct3   := curr_instruction(14 downto 12);
        
            when INST_CLASS_J =>
                v_rd_addr := curr_instruction(11 downto 7);
        
            when INST_CLASS_U =>
                v_rd_addr := curr_instruction(11 downto 7);
            
            when INST_CLASS_NOP =>
                null;
    
            when others =>
                null;
        end case;
        
        case(v_opcode) is                       -- instruction definition
            when "0110011" | "0010011" =>
                v_usage_mem := '0';
                v_usage_writeback := '1';  
                case(v_funct3) is
                    when "000" =>
                        if v_instruction_class = INST_CLASS_R then
                            if v_funct7 = "0000000" then
                                v_ALU_OP:= OP_ADD;
                            elsif v_funct7 = "0010100" then
                                v_ALU_OP:= OP_SUB;
                            end if;
                        elsif v_instruction_class = INST_CLASS_I then
                            v_ALU_OP:= OP_ADD;
                        end if;
                    when "001" =>
                        v_ALU_OP:= OP_SLL;
                    when "010" =>
                        v_ALU_OP:= OP_SLT;
                    when "011" =>
                        v_ALU_OP:= OP_SLT;
                        v_OP_SIGN:= OP_UNSIGNED;
                    when "100" =>
                        v_ALU_OP:= OP_XOR;
                    when "101" =>
                        if v_instruction_class = INST_CLASS_R then
                            if v_funct7 = "0000000" then
                                v_ALU_OP:= OP_SRL;
                            elsif v_funct7 = "0010100" then
                                v_ALU_OP:= OP_SRA;
                            end if;
                        elsif v_instruction_class = INST_CLASS_I then
                            if curr_instruction(31 downto 25) = "0000000" then  -- usage of immediate bits (11 downto 5) as funct7
                                v_ALU_OP:= OP_SRL;
                            elsif curr_instruction(31 downto 25) = "0010100" then
                                v_ALU_OP:= OP_SRA;
                            end if;
                        end if;
                    when "110" =>
                        v_ALU_OP:= OP_OR;
                    when "111" =>
                        v_ALU_OP:= OP_AND;
                    when others =>
                        v_ALU_OP:= OP_ERR;
                end case;
        
            when "0110111" =>
                v_usage_mem := '0';
                v_usage_writeback := '1';  
                v_ALU_OP:= OP_LUI;

            when "0010111" =>
                v_usage_mem := '0';
                v_usage_writeback := '1';  
                v_ALU_OP:= OP_AUIPC;

            when "0000011" => 
                v_usage_mem := '1';
                v_usage_writeback := '1';  
                v_MEM_OP:= OP_LOAD;
                v_ALU_OP:= OP_MEM;
                case(v_funct3) is
                    when "000" =>
                        v_MEM_OP_SIZE:= OP_SIZE_BYTE;
                    when "001" =>
                        v_MEM_OP_SIZE:= OP_SIZE_HALFWORD;
                    when "010" =>
                        v_MEM_OP_SIZE:= OP_SIZE_WORD;
                    when "100" =>
                        v_MEM_OP_SIZE:= OP_SIZE_BYTE;
                        v_OP_SIGN:= OP_UNSIGNED;
                    when "101" =>
                        v_MEM_OP_SIZE:= OP_SIZE_HALFWORD;
                        v_OP_SIGN:= OP_UNSIGNED;
                    when others =>
                        v_MEM_OP_SIZE:= OP_SIZE_BYTE;
                        v_OP_SIGN:= OP_UNSIGNED;
                end case;
        
            when "0100011" =>
                v_usage_mem := '1';
                v_usage_writeback := '0';  
                v_MEM_OP := OP_STORE;
                v_ALU_OP:= OP_MEM;
                case(v_funct3) is
                    when "000" =>
                        v_MEM_OP_SIZE:= OP_SIZE_BYTE;
                    when "001" =>
                        v_MEM_OP_SIZE:= OP_SIZE_HALFWORD;
                    when "010" =>
                        v_MEM_OP_SIZE:= OP_SIZE_WORD;
                    when others =>
                        v_MEM_OP := OP_LOAD;
                        v_MEM_OP_SIZE:= OP_SIZE_BYTE;
                end case;
            
            when "1100011" =>
                v_usage_mem := '0';
                v_usage_writeback := '0';
                v_ALU_OP:= OP_BR;
                case(v_funct3) is
                    when "000" =>
                        v_BRANCH_OP_COND := OP_BRANCH_EQ;
                    when "001" =>
                        v_BRANCH_OP_COND := OP_BRANCH_NE;
                    when "100" =>
                        v_BRANCH_OP_COND := OP_BRANCH_LT;
                    when "101" =>
                        v_BRANCH_OP_COND := OP_BRANCH_GE;
                    when "110" =>
                        v_BRANCH_OP_COND := OP_BRANCH_LTU;
                        v_OP_SIGN:= OP_UNSIGNED;
                    when "111" =>
                        v_BRANCH_OP_COND := OP_BRANCH_GEU;
                        v_OP_SIGN:= OP_UNSIGNED;
                    when others =>
                        v_BRANCH_OP_COND := OP_BRANCH_NE;
                end case;
                    
            when "1101111" | "1100111" => -- JAL (class INST_CLASS_J) | JALR (class INST_CLASS_I)
                v_usage_mem := '0';
                v_usage_writeback := '0';  
                if v_instruction_class = INST_CLASS_J then
                    v_ALU_OP:= OP_JAL;
                    elsif v_instruction_class = INST_CLASS_I then
                    v_usage_writeback := '1';  
                    v_ALU_OP:= OP_JALR;
                else
                    v_ALU_OP:= OP_ERR;
                end if;

            when "0000000" =>
                v_ALU_OP:= OP_NOP;
                v_usage_mem := '0';
                v_usage_writeback := '0';
            when others =>
                v_ALU_OP:= OP_ERR;
        -- when "1110011" =>                                        -- INST_CLASS_I class but for OS/debug (not yet implemented)
        --     case(v_funct3) is
        --         when "000" =>
        --             -- if imm = 0x0 -> ECALL
        --             -- elif imm = 0x1 -> EBREAK
        --     end case;
        end case;

        case(v_instruction_class) is                                -- immediate mapping
            when INST_CLASS_R =>
                null;                                               -- immediate not present in INST_CLASS_R instructions
            
            when INST_CLASS_I =>
                case(v_OP_SIGN) is
                    when OP_SIGNED =>
                        v_immediate := std_logic_vector(resize(signed(curr_instruction(31 downto 20)), 32));
                    when OP_UNSIGNED =>
                        v_immediate := std_logic_vector(resize(unsigned(curr_instruction(31 downto 20)), 32));
                end case;
                    
            when INST_CLASS_S =>
                v_immediate_12bits := curr_instruction(31 downto 25) & curr_instruction(11 downto 7);
                v_immediate := std_logic_vector(resize(signed(
                    v_immediate_12bits    
                ), 32));
                    
           when INST_CLASS_B =>
                v_immediate_13bits := curr_instruction(31) &               -- imm[12]
                                        curr_instruction(7) &              -- imm[11]
                                        curr_instruction(30 downto 25) &   -- imm[10:5]
                                        curr_instruction(11 downto 8) &    -- imm[4:1]
                                        '0';                               -- imm[0]                     
                v_immediate := std_logic_vector(resize(signed(
                    v_immediate_13bits
                ), 32));

            when INST_CLASS_U =>
                v_immediate := curr_instruction(31 downto 12) & x"000";
                -- v_immediate := std_logic_vector(resize(
                --     curr_instruction(31 downto 12) &   -- imm[31:12]
                --     x"000"                             -- imm[11:0]
                -- ), 32);

            when INST_CLASS_J =>
                v_immediate_21bits := curr_instruction(31) & -- imm[20]
                    curr_instruction(19 downto 12) &        -- imm[19:12]
                    curr_instruction(20) &                  -- imm[11]
                    curr_instruction(30 downto 21) &        -- imm[10:1]
                    '0';                                    -- imm[0]
                v_immediate := std_logic_vector(resize(signed(
                    v_immediate_21bits
                ), 32));

            when INST_CLASS_ERR =>
                v_immediate := (others => '0');
                v_usage_mem := '0';
                v_usage_writeback := '0';
                v_ALU_OP := OP_ERR;                                 -- signal the invalid instruction
                v_MEM_OP := OP_LOAD;                                -- prevent unwanted store op due to errors
            
            when INST_CLASS_NOP =>
                v_immediate := (others => '0');
                v_usage_mem := '0';
                v_usage_writeback := '0';
                v_ALU_OP := OP_NOP;
                v_MEM_OP := OP_LOAD;
            
            when others =>
                null;
        end case;
        
        case(v_instruction_class) is                                -- asynchronous/immediate registers fetch
            when INST_CLASS_R | INST_CLASS_S | INST_CLASS_B =>
                s_mem_in_rs1_addr <= v_rs1_addr;
                s_mem_in_rs2_addr <= v_rs2_addr;
                s_mem_in_read_enable <= '1';

            when  INST_CLASS_I =>
                s_mem_in_rs2_addr <= "00000";                       -- prevent unwanted readings
                s_mem_in_rs1_addr <= v_rs1_addr;
                s_mem_in_read_enable <= '1';

            when INST_CLASS_U | INST_CLASS_J =>
                s_mem_in_read_enable <= '0';

            when INST_CLASS_NOP | INST_CLASS_ERR =>
                s_mem_in_rs1_addr <= "00000";
                s_mem_in_rs2_addr <= "00000";
                s_mem_in_read_enable <= '0';
            when others =>
                null;
        end case;

        v_rs1_value := s_mem_out_rs1_value;
        v_rs2_value := s_mem_out_rs2_value;
        v_rs1_value_unsigned := unsigned(v_rs1_value);
        v_rs2_value_unsigned := unsigned(v_rs2_value);
        v_rs1_value_signed := signed(v_rs1_value);
        v_rs2_value_signed := signed(v_rs2_value);

        case(v_ALU_OP) is                                           -- Flow-control instructions
            when OP_BR =>
                v_branch_taken := '0';
                case v_BRANCH_OP_COND is
                    when OP_BRANCH_EQ => 
                        v_branch_taken := '1' when v_rs1_value_unsigned = v_rs2_value_unsigned else '0';
                    when OP_BRANCH_NE => 
                        v_branch_taken := '1' when v_rs1_value_unsigned /= v_rs2_value_unsigned else '0';
                    when OP_BRANCH_LT => 
                        v_branch_taken := '1' when v_rs1_value_signed < v_rs2_value_signed else '0';
                    when OP_BRANCH_GE => 
                        v_branch_taken := '1' when v_rs1_value_signed >= v_rs2_value_signed else '0';
                    when OP_BRANCH_LTU => 
                        v_branch_taken := '1' when v_rs1_value_unsigned < v_rs2_value_unsigned else '0';
                    when OP_BRANCH_GEU => 
                        v_branch_taken := '1' when v_rs1_value_unsigned >= v_rs2_value_unsigned else '0';
                    when others => 
                        v_branch_taken := '0';
                end case;

                v_branch_misprediction := v_branch_taken xor branch_prediction;
                if v_branch_misprediction = '0' then
                    -- correct branch prediction, create a NOP for the next stages
                    v_instruction_class := INST_CLASS_NOP;
                    v_ALU_OP := OP_NOP;
                    v_usage_mem := '0';
                    v_usage_writeback := '0';
                elsif v_branch_taken = '1' and branch_prediction = '0' then
                    -- Branch was taken, but predicted not taken (target is PC + immediate, currently at PC + 4)
                    v_branch_offset := std_logic_vector(resize(signed(std_logic_vector(signed(v_immediate)-to_signed(4, 32))), 32));
                elsif v_branch_taken = '0' and branch_prediction = '1' then
                    -- Branch was NOT taken, but predicted taken (target is PC + 4, currently at PC + immediate)
                    v_branch_offset := std_logic_vector(resize(to_signed(4, 32) - signed(v_immediate), 32));
                end if;
            when OP_JAL =>
                -- nothing to do in this stage (already done in IF)
                -- the IE stage will set the writeback signals (as JAL: rd = next_pc)
                null;
            when OP_JALR =>
                v_jump_jalr_value := AdderFunction(SIGNED_SIGNED, s_mem_out_rs1_value, v_immediate);
                v_jump_jalr_value(1 downto 0) := (others => '0');
            when others => 
                null;
        end case;

        s_instruction_class <= v_instruction_class;                 -- variables to signals mapping
        s_ALU_OP <= v_ALU_OP;
        s_MEM_OP <= v_MEM_OP;
        s_MEM_OP_SIZE <= v_MEM_OP_SIZE;
        s_OP_SIGN <= v_OP_SIGN;
        s_jump_jalr_value <= v_jump_jalr_value;
        s_branch_misprediction <= v_branch_misprediction;
        s_branch_offset <= v_branch_offset;
        s_usage_mem <= v_usage_mem;
        s_usage_writeback <= v_usage_writeback;
        s_rs1_addr <= v_rs1_addr;
        s_rs2_addr <= v_rs2_addr;
        s_rd_addr <= v_rd_addr;
        s_immediate <= v_immediate;
    end process;

    writeBackValue:process(pipe_writeback_enable, pipe_writeback_addr, pipe_writeback_value) is
    begin
        if pipe_writeback_enable = '1' then
            s_mem_in_rd_addr <= pipe_writeback_addr;
            s_mem_in_rd_value <= pipe_writeback_value;
            s_mem_in_write_enable <= '1';
        else
            s_mem_in_rd_addr <= "00000";
            s_mem_in_write_enable <= '0';
        end if;
    end process;

    pipelineRegisters: process(clock, reset)
    begin
        if reset = '1' then
            rs1_addr <= (others => '0');
            rs1_value <= (others => '0');
            rs2_addr <= (others => '0');
            rs2_value <= (others => '0');
            rd_addr <= (others => '0');
            immediate <= (others => '0');
            instruction_class <= INST_CLASS_NOP;
            ALU_OP <= OP_NOP;
            MEM_OP <= OP_LOAD;
            MEM_OP_SIZE <= OP_SIZE_WORD;
            OP_SIGN <= OP_UNSIGNED;
            usage_mem <= '0';
            usage_writeback <= '0';
            reg_pc <= (others => '0');
            s_squash_next <= '0';
        elsif rising_edge(clock) then
            if s_squash_next = '1' then
                instruction_class <= INST_CLASS_NOP;                -- single bubble creation for misprediction
                ALU_OP <= OP_NOP;
                MEM_OP <= OP_LOAD;
                MEM_OP_SIZE <= OP_SIZE_WORD;
                OP_SIGN <= OP_UNSIGNED;
                usage_mem <= '0';
                usage_writeback <= '0';
            else
                instruction_class <= s_instruction_class;
                ALU_OP <= s_ALU_OP;
                MEM_OP <= s_MEM_OP;
                MEM_OP_SIZE <= s_MEM_OP_SIZE;
                OP_SIGN <= s_OP_SIGN;
                usage_mem <= s_usage_mem;
                usage_writeback <= s_usage_writeback;
            end if;

            jump_jalr_value <= s_jump_jalr_value;
            branch_misprediction <= s_branch_misprediction;
            branch_offset <= s_branch_offset;
            s_squash_next <= s_branch_misprediction;                -- (1-cycle delay to apply the flag to the incoming instruction)

            rs1_addr <= s_rs1_addr;
            rs2_addr <= s_rs2_addr;
            rs1_value <= s_mem_out_rs1_value;
            rs2_value <= s_mem_out_rs2_value;
            rd_addr <= s_rd_addr;
            immediate <= s_immediate;
            reg_pc <= next_pc;
        end if;
    end process;
end behaviour ;
