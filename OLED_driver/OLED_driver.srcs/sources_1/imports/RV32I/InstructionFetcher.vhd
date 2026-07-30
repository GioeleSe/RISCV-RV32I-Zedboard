library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- TODO - test the new control-flow blocks :)

entity InstructionFetcher is
port (
    clock: in std_logic;
    reset: in std_logic;
    enable_fetch: in std_logic;
    branch_misprediction: in std_logic;
    branch_offset: in std_logic_vector(31 downto 0);
    jump_jalr_pc: in std_logic_vector(31 downto 0);
    branch_prediction: out std_logic;
    curr_instruction: out std_logic_vector(31 downto 0);
    reg_pc: out std_logic_vector(31 downto 0)
);
end entity InstructionFetcher;

architecture behaviour of InstructionFetcher is
    type bram_t is array (0 to 2047) of std_logic_vector(31 downto 0);
    signal bram : bram_t := (
        -- =========================================================================
        -- 1. INITIALIZATION & DATA HAZARD PADDING
        -- =========================================================================
        0  => x"00500093", -- addi x1, x0, 5   (x1 = 5)
        1  => x"00500113", -- addi x2, x0, 5   (x2 = 5)
        2  => x"00300193", -- addi x3, x0, 3   (x3 = 3)
        3  => x"00000000", -- nop              (Hazard padding for register writeback)
        4  => x"00000000", -- nop              (Hazard padding for register writeback)

        -- =========================================================================
        -- 2. CONDITIONAL BRANCH TESTS (BR / BEQ)
        -- =========================================================================
        5  => x"00208463", -- beq  x1, x2, 8   (Branch taken: 5 == 5)
        6  => x"00100213", -- addi x4, x0, 1   (SKIPPED)
        7  => x"00200213", -- addi x4, x0, 2   (x4 = 2)

        8  => x"01308463", -- beq  x1, x3, 8   (Branch NOT taken: 5 != 3, falls through)
        9  => x"00300293", -- addi x5, x0, 3   (Intermediate step)
        10 => x"00400293", -- addi x5, x0, 4   (x5 = 4)

        -- =========================================================================
        -- 3. UNCONDITIONAL JUMP TEST (JAL)
        -- =========================================================================
        11 => x"00C0006F", -- jal  x0, 12      (Unconditional jump forward)
        12 => x"00600313", -- addi x6, x0, 6   (SKIPPED)
        13 => x"00700313", -- addi x6, x0, 7   (SKIPPED)
        14 => x"00800313", -- addi x6, x0, 8   (x6 = 8)

        -- =========================================================================
        -- 4. REGISTER JUMP TEST (JALR)
        -- =========================================================================
        15 => x"04c00393", -- addi x7, x0, 76  (x7 = 76 -> targets byte address 76 / index 19)
        16 => x"00000000", -- nop              (Hazard padding for x7 writeback)
        17 => x"00038067", -- jalr x0, 0(x7)   (JALR with rd=x0; jumps to address 76)
        18 => x"00000000", -- nop              (JALR delay slot / masked instruction)
        19 => x"00900413", -- addi x8, x0, 9   (Jump destination: x8 = 9)

        others => (others => '0')
    );
    signal s_mem_addr: std_logic_vector(10 downto 0) := (others => '0');
    signal s_curr_instruction: std_logic_vector(31 downto 0) := (others => '0');
    signal s_pc: std_logic_vector(31 downto 0) := (others => '0');
    
    signal s_branch_prediction: std_logic := '0';
    signal s_branch_prediction_offset: std_logic_vector(31 downto 0) := (others => '0');
    signal s_branch_pending: std_logic_vector(1 downto 0) := (others => '0');
    signal s_jump_pending: std_logic_vector(1 downto 0) := (others => '0'); -- the numbers of cycles to wait for the jump (normal instructions = "00", JAL = "01", JALR = "11" at first bubble and "10" at second bubble)
    signal s_jump_jal_offset: std_logic_vector(31 downto 0) := (others => '0');
begin
    
    s_mem_addr <= s_pc(12 downto 2);                                -- each instruction is 4 byte -> can ignore the 2 LSB
    instructionFetch: process(clock, reset)
        variable v_pc: std_logic_vector(31 downto 0) := (others => '0');
        variable v_next_pc: std_logic_vector(31 downto 0) := (others => '0');
        variable v_curr_instruction: std_logic_vector(31 downto 0) := (others => '0');
        variable v_curr_opcode: std_logic_vector(6 downto 0) := (others => '0');
        variable v_immediate_13bits: std_logic_vector(12 downto 0) := (others => '0');
        variable v_immediate_21bits: std_logic_vector(20 downto 0) := (others => '0');
        variable v_branch_prediction_taken: std_logic := '0';
        variable v_branch_pending: std_logic_vector(1 downto 0) := (others => '0');
        variable v_mask_instruction: std_logic := '0';
        variable v_pc_offset: std_logic_vector(31 downto 0) := (others => '0');
    begin
        if reset = '1' then
            s_curr_instruction <= (others => '0');
            s_pc <= (others => '0');
            curr_instruction <= (others => '0');
            reg_pc <= (others => '0');
            s_jump_pending <= (others => '0');
            s_jump_jal_offset <= (others => '0');
            s_branch_prediction <= '0';
        elsif rising_edge(clock) then
            if enable_fetch = '1' then
                case (s_jump_pending) is
                    when "01" =>
                        s_jump_pending <= "00";
                        v_pc_offset := std_logic_vector(signed(s_jump_jal_offset) - to_signed(4, 32));

                        -- v_pc_offset :=  (signed(s_jump_jal_offset) - unsigned(4)); -- JAL: PC += imm (-4 to get back to the jump address)
                    when "11" =>
                        s_jump_pending <= "10";
                        v_mask_instruction := '1';
                    when "10" =>                                    -- JALR executed by ID, new PC
                        v_mask_instruction := '0';
                        v_pc_offset := (others => '0');
                        v_pc := jump_jalr_pc;                       -- JALR: PC = rs1+imm
                    when "00" =>
                        v_pc_offset := (others => '0');
                        v_pc := s_pc;
                    when others =>
                        v_pc_offset := (others => '0');
                        null;
                end case;
                case (s_branch_pending) is
                    when "11" =>                                    -- there has been a branch prediction
                        if s_branch_prediction = '1' then           -- the prediction is branch_taken = '1'
                            v_pc_offset := std_logic_vector(signed(s_branch_prediction_offset) - to_signed(4, 32)); -- predicted instruction
                        elsif s_branch_prediction = '0' then        -- expected a regular flow
                            v_pc_offset := (others => '0');
                            v_pc := s_pc;                           -- simply use the next pc
                        end if;
                        s_branch_pending <= "10";                   -- check at the next cycle if the prediction was correct
                    when "10" =>
                        s_branch_pending <= "00";
                        if branch_misprediction = '1' then          -- use directly the offset computed by ID
                            v_pc_offset := branch_offset;           -- take the input offset as it's prepared for any rollback (from next_pc or from branch-pointed_pc)
                        end if;
                    when others =>
                        v_pc_offset := (others => '0');
                        null;
                end case;

                v_pc := std_logic_vector(unsigned(v_pc) + unsigned(v_pc_offset));
                v_next_pc := std_logic_vector(signed(v_pc) + to_signed(4, 32));
                v_curr_instruction := bram(to_integer(unsigned(v_pc(12 downto 2))));
                v_curr_opcode := v_curr_instruction(6 downto 0);
                
                if v_mask_instruction = '1' then
                    v_curr_instruction(6 downto 0) := "0000000";    -- opcode for NOP instruction
                end if;

                case(v_curr_opcode) is
                    when "1101111" => -- JAL
                        v_immediate_21bits := v_curr_instruction(31) & -- imm[20]
                            v_curr_instruction(19 downto 12) &      -- imm[19:12]
                            v_curr_instruction(20) &                -- imm[11]
                            v_curr_instruction(30 downto 21) &      -- imm[10:1]
                            '0';                                    -- imm[0]
                        s_jump_jal_offset <= std_logic_vector(resize(signed(v_curr_instruction), 32)); -- sign-extension for possible negative offsets
                        s_jump_pending <= "01";
                    when "1100111" => -- JALR
                        s_jump_pending <= "11";
                    when "1100011" => -- BR
                        v_branch_pending:= "11";
                        v_branch_prediction_taken := v_curr_instruction(31);  -- negative offset -> branch prediction = taken
                        if v_branch_prediction_taken = '1' then                      
                            v_immediate_13bits := v_curr_instruction(31) & -- imm[12]
                                v_curr_instruction(7) &                 -- imm[11]
                                v_curr_instruction(30 downto 25) &      -- imm[10:5]
                                v_curr_instruction(11 downto 8) &       -- imm[4:1]
                                '0';                                    -- imm[0]
                            s_branch_prediction_offset <= std_logic_vector(resize(signed(v_immediate_13bits), 32));
                        end if;
                    when others =>
                        null;
                end case;

                s_pc <= v_next_pc;
                s_branch_pending <= v_branch_pending;
                s_branch_prediction <= v_branch_prediction_taken;
                branch_prediction <= s_branch_prediction;
                curr_instruction <= v_curr_instruction;
                reg_pc <= v_next_pc;
            end if;
        end if;
    end process;
end architecture;