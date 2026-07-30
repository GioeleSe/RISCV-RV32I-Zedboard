library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package common is
    type REG_MEMORY_T is array (0 to 31) of std_logic_vector(31 downto 0); -- 1024 bit memory definition (32x32)
    type BRAM_T is array (0 to 4095) of std_logic_vector(31 downto 0); -- Word-wide BRAM array (16 KB total: 4096 words * 32 bits = 131,072 bits)
    type INST_CLASS_T is(
        INST_CLASS_R, INST_CLASS_I, INST_CLASS_S, INST_CLASS_B, INST_CLASS_U, INST_CLASS_J, INST_CLASS_NOP, INST_CLASS_ERR
    );
    type ALU_OP_T is(
        OP_ADD,
        OP_SUB,
        OP_AND,
        OP_OR,
        OP_XOR,
        OP_SLL,
        OP_SRL,
        OP_SRA,
        OP_SLT,
        OP_LUI,
        OP_AUIPC,
        OP_BR,
        OP_JAL,
        OP_JALR,
        OP_MEM,
        OP_NOP,
        OP_ERR
    );
    type MEM_OP_T is(
        OP_LOAD,
        OP_STORE
    );
    type MEM_OP_SIZE_T is(
        OP_SIZE_BYTE,
        OP_SIZE_HALFWORD,
        OP_SIZE_WORD
    );
    type BRANCH_OP_COND_T is(
        OP_BRANCH_EQ,
        OP_BRANCH_NE,
        OP_BRANCH_LT,
        OP_BRANCH_LTU,
        OP_BRANCH_GEU,
        OP_BRANCH_GE,
        OP_BRANCH_ERR
    );
    type OP_SIGN_T is(
        OP_SIGNED,
        OP_UNSIGNED
    );
    type ADDITION_TYPE_T is (UNSIGNED_UNSIGNED, SIGNED_SIGNED, UNSIGNED_SIGNED);
    function AdderFunction (
        addition_type : ADDITION_TYPE_T;
        n1 : std_logic_vector(31 downto 0);
        n2 : std_logic_vector(31 downto 0)
    ) return std_logic_vector;
end package common;

package body common is
    -- Function implementation in package body
    function AdderFunction (
        addition_type : ADDITION_TYPE_T;
        n1 : std_logic_vector(31 downto 0);
        n2 : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
        variable v_result : std_logic_vector(31 downto 0);
        variable temp_33bit : signed(32 downto 0);
        variable u_n1 : unsigned(31 downto 0);
        variable s_n1 : signed(31 downto 0);
        variable u_n2 : unsigned(31 downto 0);
        variable s_n2 : signed(31 downto 0);
    begin
        -- Convert inputs to appropriate types
        u_n1 := unsigned(n1);
        s_n1 := signed(n1);
        u_n2 := unsigned(n2);
        s_n2 := signed(n2);
        
        case addition_type is
            when UNSIGNED_UNSIGNED =>
                v_result := std_logic_vector(u_n1 + u_n2);
                
            when SIGNED_SIGNED =>
                v_result := std_logic_vector(s_n1 + s_n2);
                
            when UNSIGNED_SIGNED =>
                -- Convert unsigned to 33-bit signed (zero-extend), then add
                temp_33bit := resize(signed('0' & n1), 33) + resize(s_n2, 33);
                
                -- Saturating arithmetic
                if temp_33bit > 2147483647 then  -- 2**31 - 1
                    v_result := X"7FFFFFFF"; -- Max positive signed
                elsif temp_33bit < 0 then
                    v_result := (others => '0'); -- Clamp to 0 for unsigned
                else
                    v_result := std_logic_vector(resize(temp_33bit, 32));
                end if;
        end case;

        return v_result;
    end function AdderFunction;
end package body common;