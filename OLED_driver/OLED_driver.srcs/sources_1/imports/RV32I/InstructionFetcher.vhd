library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

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
    signal bram : BRAM_T := (
    -- =========================================================================
    -- INITIALIZATION & INITIAL OLED POSITION SETUP
    -- =========================================================================
    0  => x"00f00513", -- addi x10, x0, 15     (Load 15 into x10)
    -- 4 Padding operations
    1  => x"00000013", -- addi x0,  x0, 0      
    2  => x"00000013", -- addi x0,  x0, 0      
    3  => x"00000013", -- addi x0,  x0, 0      
    4  => x"00000013", -- addi x0,  x0, 0      
    5  => x"01051513", -- slli x10, x10, 16    (Base address 0x000F0000)
    6  => x"04000293", -- addi x5,  x0, 64     (Initial pos_x = 64)
    7  => x"00e00313", -- addi x6,  x0, 14     (Initial pos_y = 14)

    -- Pack initial position into x7 and send
    8  => x"00831393", -- slli x7,  x6, 8      
    -- 4 Padding operations
    9  => x"00000013", -- addi x0,  x0, 0      
    10 => x"00000013", -- addi x0,  x0, 0      
    11 => x"00000013", -- addi x0,  x0, 0      
    12 => x"00000013", -- addi x0,  x0, 0      
    13 => x"0053e3b3", -- or   x7,  x7, x5     
    -- 4 Padding operations
    14 => x"00000013", -- addi x0,  x0, 0      
    15 => x"00000013", -- addi x0,  x0, 0      
    16 => x"00000013", -- addi x0,  x0, 0      
    17 => x"00000013", -- addi x0,  x0, 0      
    18 => x"00752223", -- sw   x7,  4(x10)     (Store initial position at 0x000F0004)

    -- =========================================================================
    -- BUTTON POLLING LOOP START (Index 19)
    -- =========================================================================
    19 => x"00052083", -- lw   x1,  0(x10)     (Load button state from 0x000F0000)
    20 => x"00000000", -- nop                   (Load-use hazard padding 1)
    21 => x"00000000", -- nop                   (Load-use hazard padding 2)
    22 => x"00000000", -- nop                   (Load-use hazard padding 3)
    23 => x"00000000", -- nop                   (Load-use hazard padding 4)

    -- =========================================================================
    -- EXTRACT BITS 0, 1, 2, 3 INTO REGISTERS
    -- =========================================================================
    24 => x"0010f113", -- andi x2,  x1, 1      (Up -> x2, already 0/1)
    25 => x"0020f193", -- andi x3,  x1, 2      (Down -> x3, raw bit = 0/2)
    26 => x"0040f213", -- andi x4,  x1, 4      (Left -> x4, raw bit = 0/4)
    27 => x"0080f593", -- andi x11, x1, 8      (Right -> x11, raw bit = 0/8)
    28 => x"00000013", -- nop                   (hazard padding 1)
    29 => x"00000013", -- nop                   (hazard padding 2)
    30 => x"00000013", -- nop                   (hazard padding 3)
    31 => x"00000013", -- nop                   (hazard padding 4)

    -- =========================================================================
    -- NORMALIZE DOWN/LEFT/RIGHT BITS TO 0/1 (Up was already 0/1 from bit 0)
    -- =========================================================================
    32 => x"0011d193", -- srli x3,  x3, 1      (Down -> 0/1)
    33 => x"00225213", -- srli x4,  x4, 2      (Left -> 0/1)
    34 => x"0035d593", -- srli x11, x11, 3     (Right -> 0/1)
    35 => x"00000013", -- nop                   (hazard padding 1)
    36 => x"00000013", -- nop                   (hazard padding 2)
    37 => x"00000013", -- nop                   (hazard padding 3)
    38 => x"00000013", -- nop                   (hazard padding 4)

    -- =========================================================================
    -- COMPUTE DELTAS SAFELY WITH HAZARD PADDING
    -- =========================================================================
    39 => x"40218e33", -- sub  x28, x3, x2     (Delta Y = Down - Up)
    40 => x"40458eb3", -- sub  x29, x11, x4    (Delta X = Right - Left)
    41 => x"00000013", -- nop                   (Pipeline padding 1)
    42 => x"00000013", -- nop                   (Pipeline padding 2)
    43 => x"00000013", -- nop                   (Pipeline padding 3)
    44 => x"00000013", -- nop                   (Pipeline padding 4)

    -- =========================================================================
    -- APPLY DELTAS TO Y AND X POSITIONS
    -- =========================================================================
    45 => x"01c30333", -- add  x6,  x6, x28    (Y = Y + Delta Y)
    46 => x"00000013", -- nop                   (Pipeline padding 1)
    47 => x"00000013", -- nop                   (Pipeline padding 2)
    48 => x"00000013", -- nop                   (Pipeline padding 3)
    49 => x"00000013", -- nop                   (Pipeline padding 4)
    50 => x"01d282b3", -- add  x5,  x5, x29    (X = X + Delta X)
    51 => x"00000013", -- nop                   (Pipeline padding 1)
    52 => x"00000013", -- nop                   (Pipeline padding 2)
    53 => x"00000013", -- nop                   (Pipeline padding 3)
    54 => x"00000013", -- nop                   (Pipeline padding 4)

    -- =========================================================================
    -- SEND UPDATED POSITION TO OLED CONTROLLER
    -- =========================================================================
    55 => x"00831393", -- slli x7,  x6, 8      
    56 => x"00000013", -- nop                   (hazard padding 1)
    57 => x"00000013", -- nop                   (hazard padding 2)
    58 => x"00000013", -- nop                   (hazard padding 3)
    59 => x"00000013", -- nop                   (hazard padding 4)
    60 => x"0053e3b3", -- or   x7,  x7, x5     
    61 => x"00000013", -- nop                   (hazard padding 1)
    62 => x"00000013", -- nop                   (hazard padding 2)
    63 => x"00000013", -- nop                   (hazard padding 3)
    64 => x"00000013", -- nop                   (hazard padding 4)
    65 => x"00752223", -- sw   x7,  4(x10)     (Store new position at 0x000F0004)

    -- =========================================================================
    -- LOOP BACK TO POLLING START (Index 19)
    -- =========================================================================
    66 => x"f45ff06f", -- jal  x0, -188       (Unconditional jump back to index 19)
    67 => x"00000013", -- nop
    68 => x"00000013", -- nop

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
                        v_pc := s_pc;
                        
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
                v_pc := std_logic_vector(signed(v_pc) + signed(v_pc_offset));
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
                        s_jump_jal_offset <= std_logic_vector(resize(signed(v_immediate_21bits), 32)); -- FIXED: sign-extend the extracted immediate
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