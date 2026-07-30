library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity RegisterFile is
    port(
        clock: in std_logic;
        reset: in std_logic;
        
        addr_A: in std_logic_vector(4 downto 0);
        addr_B: in std_logic_vector(4 downto 0);
        read_enable: in std_logic;
        
        addr_C: in std_logic_vector(4 downto 0);                    -- write operations use a dedicated port
        write_C: in std_logic_vector(31 downto 0);
        write_enable: in std_logic;

        val_A: out std_logic_vector(31 downto 0);
        val_B: out std_logic_vector(31 downto 0);
        
        regs: out REG_MEMORY_T
    );
end entity;

architecture behaviour of RegisterFile is
    signal reg_memory: REG_MEMORY_T := (others => (others => '0')); -- start with all registers to 0
    
    begin
        process(clock)                                              -- only write operations are synchronous
        begin
            if reset = '1' then
                reg_memory <= (others => (others => '0'));
            elsif rising_edge(clock) then
                if write_enable = '1' then
                    if addr_C /= "00000" then                       -- don't write on x0
                        reg_memory(to_integer(unsigned(addr_C))) <= write_C;
                    end if;
                end if;
            end if;
        if read_enable = '1' then                                   -- bit gate to prevent unwanted memory operations
            val_A <= (others => '0') when addr_A = "00000" else reg_memory(to_integer(unsigned(addr_A)));
            val_B <= (others => '0') when addr_B = "00000" else reg_memory(to_integer(unsigned(addr_B)));
        else
            val_A <= (others => '0');
            val_B <= (others => '0');
        end if;
    end process;
    regs <= reg_memory;
end architecture;