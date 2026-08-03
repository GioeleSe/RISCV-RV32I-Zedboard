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
        
        addr_C: in std_logic_vector(4 downto 0);
        write_C: in std_logic_vector(31 downto 0);
        write_enable: in std_logic;

        val_A: out std_logic_vector(31 downto 0);
        val_B: out std_logic_vector(31 downto 0);
        
        regs: out REG_MEMORY_T
    );
end entity RegisterFile;

architecture behavior of RegisterFile is
    signal reg_memory: REG_MEMORY_T := (others => (others => '0'));
begin

    write_proc: process(clock, reset)
    begin
        if reset = '1' then
            reg_memory <= (others => (others => '0'));
        elsif rising_edge(clock) then
            if write_enable = '1' then
                if addr_C /= "00000" then
                    reg_memory(to_integer(unsigned(addr_C))) <= write_C;
                end if;
            end if;
        end if;
    end process write_proc;

    read_proc: process(read_enable, addr_A, addr_B, reg_memory)
    begin
        if read_enable = '1' then
            if addr_A = "00000" then
                val_A <= (others => '0');
            else
                val_A <= reg_memory(to_integer(unsigned(addr_A)));
            end if;

            if addr_B = "00000" then
                val_B <= (others => '0');
            else
                val_B <= reg_memory(to_integer(unsigned(addr_B)));
            end if;
        else
            val_A <= (others => '0');
            val_B <= (others => '0');
        end if;
    end process read_proc;

    regs <= reg_memory;
end architecture behavior;