library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity rv32i_top is
    port (
        clock                 : in std_logic;
        reset                 : in std_logic;

        -- Memory-mapped button inputs (MMIO read at 0x000F0000)
        btn_up                : in std_logic := '0';
        btn_down              : in std_logic := '0';
        btn_left              : in std_logic := '0';
        btn_right             : in std_logic := '0';

        -- Memory-mapped OLED command register (MMIO write/read at 0x000F0004)
        oled_cmd_reg_out      : out std_logic_vector(31 downto 0)
    );
end entity rv32i_top;

architecture structural of rv32i_top is

    -- Component Declarations for RV32I Pipeline Stages
    component InstructionFetcher is
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
    end component;

    component InstructionDecoder is
    port(
        clock: in std_logic;
        reset: in std_logic;
        curr_instruction: in std_logic_vector(31 downto 0);
        next_pc: in std_logic_vector(31 downto 0);
        branch_prediction: in std_logic;
        pipe_writeback_enable: in std_logic;
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

        jump_jalr_value: out std_logic_vector(31 downto 0);
        branch_misprediction: out std_logic;
        branch_offset: out std_logic_vector(31 downto 0);

        usage_mem: out std_logic;
        usage_writeback: out std_logic;
        reg_pc: out std_logic_vector(31 downto 0);
        regs_dump: out REG_MEMORY_T
    );
    end component;

    component InstructionExecution is
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
        usage_writeback_out: out std_logic
    );
    end component;

    component MemoryAccess is
    port (
        clock: in std_logic;
        reset: in std_logic;
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
        pipe_writeback_value_out: out std_logic_vector(31 downto 0);
        oled_cmd_reg: out std_logic_vector(31 downto 0)
    );
    end component;

    -- Pipeline Interconnection Signals
    signal s_curr_instruction        : std_logic_vector(31 downto 0);
    signal s_if_reg_pc               : std_logic_vector(31 downto 0);
    signal s_branch_prediction       : std_logic;
    
    signal s_branch_misprediction    : std_logic;
    signal s_branch_offset           : std_logic_vector(31 downto 0);
    signal s_jump_jalr_value         : std_logic_vector(31 downto 0);
    signal s_id_rs1_addr             : std_logic_vector(4 downto 0);
    signal s_id_rs1_value            : std_logic_vector(31 downto 0);
    signal s_id_rs2_addr             : std_logic_vector(4 downto 0);
    signal s_id_rs2_value            : std_logic_vector(31 downto 0);
    signal s_id_rd_addr              : std_logic_vector(4 downto 0);
    signal s_id_immediate            : std_logic_vector(31 downto 0);
    signal s_id_instruction_class    : INST_CLASS_T;
    signal s_id_alu_op               : ALU_OP_T;
    signal s_id_mem_op               : MEM_OP_T;
    signal s_id_mem_op_size          : MEM_OP_SIZE_T;
    signal s_id_op_sign              : OP_SIGN_T;
    signal s_id_usage_mem            : std_logic;
    signal s_id_usage_writeback      : std_logic;
    signal s_id_reg_pc               : std_logic_vector(31 downto 0);
    signal s_regs_dump               : REG_MEMORY_T;

    signal s_ie_rs1_addr_out         : std_logic_vector(4 downto 0);
    signal s_ie_rs1_value_out        : std_logic_vector(31 downto 0);
    signal s_ie_rs2_addr_out         : std_logic_vector(4 downto 0);
    signal s_ie_rs2_value_out        : std_logic_vector(31 downto 0);
    signal s_ie_rd_addr_out          : std_logic_vector(4 downto 0);
    signal s_ie_rd_value_out         : std_logic_vector(31 downto 0);
    signal s_ie_reg_pc               : std_logic_vector(31 downto 0);
    signal s_ie_mem_addr_out         : std_logic_vector(31 downto 0);
    signal s_ie_mem_op_out           : MEM_OP_T;
    signal s_ie_mem_op_size_out      : MEM_OP_SIZE_T;
    signal s_ie_op_sign_out          : OP_SIGN_T;
    signal s_ie_usage_mem_out        : std_logic;
    signal s_ie_usage_writeback_out  : std_logic;

    signal s_wb_enable               : std_logic;
    signal s_wb_addr                 : std_logic_vector(4 downto 0);
    signal s_wb_value                : std_logic_vector(31 downto 0);

begin

    Inst_Fetcher: InstructionFetcher
    port map (
        clock                => clock,
        reset                => reset,
        enable_fetch         => '1',
        branch_misprediction => s_branch_misprediction,
        branch_offset        => s_branch_offset,
        jump_jalr_pc         => s_jump_jalr_value,
        branch_prediction    => s_branch_prediction,
        curr_instruction     => s_curr_instruction,
        reg_pc               => s_if_reg_pc
    );

    Inst_Decoder: InstructionDecoder
    port map (
        clock                 => clock,
        reset                 => reset,
        curr_instruction      => s_curr_instruction,
        next_pc               => s_if_reg_pc,
        branch_prediction     => s_branch_prediction,
        pipe_writeback_enable => s_wb_enable,
        pipe_writeback_addr   => s_wb_addr,
        pipe_writeback_value  => s_wb_value,
        rs1_addr              => s_id_rs1_addr,
        rs1_value             => s_id_rs1_value,
        rs2_addr              => s_id_rs2_addr,
        rs2_value             => s_id_rs2_value,
        rd_addr               => s_id_rd_addr,
        immediate             => s_id_immediate,
        instruction_class     => s_id_instruction_class,
        ALU_OP                => s_id_alu_op,
        MEM_OP                => s_id_mem_op,
        MEM_OP_SIZE           => s_id_mem_op_size,
        OP_SIGN               => s_id_op_sign,
        jump_jalr_value       => s_jump_jalr_value,
        branch_misprediction  => s_branch_misprediction,
        branch_offset         => s_branch_offset,
        usage_mem             => s_id_usage_mem,
        usage_writeback       => s_id_usage_writeback,
        reg_pc                => s_id_reg_pc,
        regs_dump             => s_regs_dump
    );

    Inst_Execution: InstructionExecution
    port map (
        clock               => clock,
        reset               => reset,
        next_pc             => s_id_reg_pc,
        rs1_addr            => s_id_rs1_addr,
        rs1_value           => s_id_rs1_value,
        rs2_addr            => s_id_rs2_addr,
        rs2_value           => s_id_rs2_value,
        rd_addr             => s_id_rd_addr,
        immediate           => s_id_immediate,
        instruction_class   => s_id_instruction_class,
        ALU_OP              => s_id_alu_op,
        MEM_OP              => s_id_mem_op,
        MEM_OP_SIZE         => s_id_mem_op_size,
        OP_SIGN             => s_id_op_sign,
        usage_mem           => s_id_usage_mem,
        usage_writeback     => s_id_usage_writeback,
        rs1_addr_out        => s_ie_rs1_addr_out,
        rs1_value_out       => s_ie_rs1_value_out,
        rs2_addr_out        => s_ie_rs2_addr_out,
        rs2_value_out       => s_ie_rs2_value_out,
        rd_addr_out         => s_ie_rd_addr_out,
        rd_value_out        => s_ie_rd_value_out,
        reg_pc              => s_ie_reg_pc,
        mem_addr_out        => s_ie_mem_addr_out,
        MEM_OP_out          => s_ie_mem_op_out,
        MEM_OP_SIZE_out     => s_ie_mem_op_size_out,
        OP_SIGN_out         => s_ie_op_sign_out,
        usage_mem_out       => s_ie_usage_mem_out,
        usage_writeback_out => s_ie_usage_writeback_out
    );

    Inst_MemoryAccess: MemoryAccess
    port map (
        clock                     => clock,
        reset                     => reset,
        btn_up                    => btn_up,
        btn_down                  => btn_down,
        btn_left                  => btn_left,
        btn_right                 => btn_right,
        rs1_addr_in               => s_ie_rs1_addr_out,
        rs1_value_in              => s_ie_rs1_value_out,
        rs2_addr_in               => s_ie_rs2_addr_out,
        rs2_value_in              => s_ie_rs2_value_out,
        rd_addr_in                => s_ie_rd_addr_out,
        rd_value_in               => s_ie_rd_value_out,
        next_pc                   => s_ie_reg_pc,
        usage_mem_in              => s_ie_usage_mem_out,
        mem_addr_in               => s_ie_mem_addr_out,
        MEM_OP_in                 => s_ie_mem_op_out,
        MEM_OP_SIZE_in            => s_ie_mem_op_size_out,
        OP_SIGN_in                => s_ie_op_sign_out,
        usage_writeback_in        => s_ie_usage_writeback_out,
        rs1_addr_out              => open,
        rs1_value_out             => open,
        rs2_addr_out              => open,
        rs2_value_out             => open,
        pipe_writeback_enable_out => s_wb_enable,
        pipe_writeback_addr_out   => s_wb_addr,
        pipe_writeback_value_out  => s_wb_value,
        oled_cmd_reg              => oled_cmd_reg_out
    );

end architecture structural;