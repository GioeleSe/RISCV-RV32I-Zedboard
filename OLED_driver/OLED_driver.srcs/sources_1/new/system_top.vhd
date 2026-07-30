-- ============================================================================
-- System Top-Level: Integrates CPU Pipeline, MMIO Buttons, and OLED Controller
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.common.all;

entity system_top is
    port (
        clock       : in  std_logic;
        reset       : in  std_logic;
        
        -- Physical Push Button Inputs (mapped to button_controller inside MemoryAccess)
        btn_up      : in  std_logic;
        btn_down    : in  std_logic;
        btn_left    : in  std_logic;
        btn_right   : in  std_logic;
        
        -- Physical OLED Display Interface Pins
        oled_sdin   : out std_logic;
        oled_sclk   : out std_logic;
        oled_dc     : out std_logic;
        oled_res    : out std_logic;
        oled_vbat   : out std_logic;
        oled_vdd    : out std_logic
    );
end entity system_top;

architecture structural of system_top is

    -- Pipeline & Control Signals (matching testbench architecture flow)
    signal s_branch_misprediction : std_logic;
    signal s_branch_offset        : std_logic_vector(31 downto 0);
    signal s_jump_jalr_pc         : std_logic_vector(31 downto 0);
    signal s_branch_prediction    : std_logic;
    signal s_curr_instruction     : std_logic_vector(31 downto 0);
    signal s_jump_jalr_value      : std_logic_vector(31 downto 0);
    
    signal s_next_pc_1            : std_logic_vector(31 downto 0) := (others => '0');
    signal s_next_pc_2            : std_logic_vector(31 downto 0) := (others => '0');
    signal s_next_pc_3            : std_logic_vector(31 downto 0) := (others => '0');

    signal s_rs1_addr             : std_logic_vector(4 downto 0) := (others => '0');
    signal s_rs1_value            : std_logic_vector(31 downto 0);
    signal s_rs2_addr             : std_logic_vector(4 downto 0) := (others => '0');
    signal s_rs2_value            : std_logic_vector(31 downto 0);
    signal s_rd_addr              : std_logic_vector(4 downto 0) := (others => '0');
    signal s_immediate            : std_logic_vector(31 downto 0);
    signal s_instruction_class    : INST_CLASS_T;
    signal s_ALU_OP               : ALU_OP_T;
    signal s_MEM_OP               : MEM_OP_T;
    signal s_MEM_OP_SIZE          : MEM_OP_SIZE_T;
    signal s_OP_SIGN              : OP_SIGN_T;
    signal s_BRANCH_OP_COND       : BRANCH_OP_COND_T;
    signal s_usage_mem            : std_logic;
    signal s_usage_writeback      : std_logic;
    signal s_regs_dump            : REG_MEMORY_T;

    -- Execution Stage Outputs
    signal s_ieout_rs1_addr_out   : std_logic_vector(4 downto 0);
    signal s_ieout_rs1_value_out  : std_logic_vector(31 downto 0);
    signal s_ieout_rs2_addr_out   : std_logic_vector(4 downto 0);
    signal s_ieout_rs2_value_out  : std_logic_vector(31 downto 0);
    signal s_ieout_rd_addr_out    : std_logic_vector(4 downto 0);
    signal s_ieout_rd_value_out   : std_logic_vector(31 downto 0);
    signal s_ieout_mem_addr_out   : std_logic_vector(31 downto 0);
    signal s_ieout_MEM_OP_out     : MEM_OP_T;
    signal s_ieout_MEM_OP_SIZE_out: MEM_OP_SIZE_T;
    signal s_ieout_OP_SIGN_out    : OP_SIGN_T;
    signal s_ieout_usage_mem_out  : std_logic;
    signal s_ieout_usage_writeback_out : std_logic;

    -- Memory Access Stage Outputs
    signal s_memout_pipe_writeback_enable_out : std_logic;
    signal s_memout_pipe_writeback_addr_out   : std_logic_vector(4 downto 0);
    signal s_memout_pipe_writeback_value_out  : std_logic_vector(31 downto 0);
    signal s_memout_rs1_addr_out              : std_logic_vector(4 downto 0);
    signal s_memout_rs1_value_out             : std_logic_vector(31 downto 0);
    signal s_memout_rs2_addr_out              : std_logic_vector(4 downto 0);
    signal s_memout_rs2_value_out             : std_logic_vector(31 downto 0);

    -- MMIO / OLED Command Interconnect
    signal s_oled_cmd_data                    : std_logic_vector(31 downto 0);

begin

    -- 1. Instruction Fetcher Stage
    InstructionFetcherEntity: entity work.InstructionFetcher
    port map(
        clock                => clock,
        reset                => reset,
        enable_fetch         => '1',
        branch_misprediction => s_branch_misprediction,
        branch_offset        => s_branch_offset, 
        jump_jalr_pc         => s_jump_jalr_pc, 
        branch_prediction    => s_branch_prediction, 
        curr_instruction     => s_curr_instruction, 
        reg_pc               => s_next_pc_1
    );

    -- 2. Instruction Decoder Stage
    instructionDecoderEntity: entity work.InstructionDecoder
    port map(
        clock                 => clock,
        reset                 => reset,
        curr_instruction      => s_curr_instruction,
        next_pc               => s_next_pc_1,
        branch_prediction     => s_branch_prediction,
        pipe_writeback_enable => s_memout_pipe_writeback_enable_out,
        pipe_writeback_addr   => s_memout_pipe_writeback_addr_out,
        pipe_writeback_value  => s_memout_pipe_writeback_value_out,
        rs1_addr              => s_rs1_addr,
        rs1_value             => s_rs1_value,
        rs2_addr              => s_rs2_addr,
        rs2_value             => s_rs2_value,
        rd_addr               => s_rd_addr,
        immediate             => s_immediate,
        instruction_class     => s_instruction_class,
        ALU_OP                => s_ALU_OP,
        MEM_OP                => s_MEM_OP,
        MEM_OP_SIZE           => s_MEM_OP_SIZE,
        OP_SIGN               => s_OP_SIGN,
        jump_jalr_value       => s_jump_jalr_value,
        branch_misprediction  => s_branch_misprediction,
        branch_offset         => s_branch_offset,
        usage_mem             => s_usage_mem,
        usage_writeback       => s_usage_writeback,
        reg_pc                => s_next_pc_2,
        regs_dump             => s_regs_dump
    );
    
    -- 3. Instruction Execution Stage
    instructionExecutionEntity: entity work.InstructionExecution
    port map(
        clock                 => clock,
        reset                 => reset,
        next_pc               => s_next_pc_2,
        rs1_addr              => s_rs1_addr,
        rs1_value             => s_rs1_value,
        rs2_addr              => s_rs2_addr,
        rs2_value             => s_rs2_value,
        rd_addr               => s_rd_addr,
        immediate             => s_immediate,
        instruction_class     => s_instruction_class,
        ALU_OP                => s_ALU_OP,
        MEM_OP                => s_MEM_OP,
        MEM_OP_SIZE           => s_MEM_OP_SIZE,
        OP_SIGN               => s_OP_SIGN,
        usage_mem             => s_usage_mem,
        usage_writeback       => s_usage_writeback,
        rs1_addr_out          => s_ieout_rs1_addr_out,
        rs1_value_out         => s_ieout_rs1_value_out,
        rs2_addr_out          => s_ieout_rs2_addr_out,
        rs2_value_out         => s_ieout_rs2_value_out,
        rd_addr_out           => s_ieout_rd_addr_out,
        rd_value_out          => s_ieout_rd_value_out,
        reg_pc                => s_next_pc_3,
        mem_addr_out          => s_ieout_mem_addr_out,
        MEM_OP_out            => s_ieout_MEM_OP_out,
        MEM_OP_SIZE_out       => s_ieout_MEM_OP_SIZE_out,
        OP_SIGN_out           => s_ieout_OP_SIGN_out,
        usage_mem_out         => s_ieout_usage_mem_out,
        usage_writeback_out   => s_ieout_usage_writeback_out
    );
    
    -- 4. Memory Access Stage (Includes Button Controller & MMIO handling)
    memoryAccessEntity: entity work.MemoryAccess
    port map(
        clock                     => clock,
        reset                     => reset,
        btn_up                    => btn_up,
        btn_down                  => btn_down,
        btn_left                  => btn_left,
        btn_right                 => btn_right,
        rs1_addr_in               => s_ieout_rs1_addr_out,
        rs1_value_in              => s_ieout_rs1_value_out,
        rs2_addr_in               => s_ieout_rs2_addr_out,
        rs2_value_in              => s_ieout_rs2_value_out,
        rd_addr_in                => s_ieout_rd_addr_out,
        rd_value_in               => s_ieout_rd_value_out,
        next_pc                   => s_next_pc_3,
        usage_mem_in              => s_ieout_usage_mem_out,
        mem_addr_in               => s_ieout_mem_addr_out,
        MEM_OP_in                 => s_ieout_MEM_OP_out,
        MEM_OP_SIZE_in            => s_ieout_MEM_OP_SIZE_out,
        OP_SIGN_in                => s_ieout_OP_SIGN_out,
        usage_writeback_in        => s_ieout_usage_writeback_out,
        rs1_addr_out              => s_memout_rs1_addr_out,
        rs1_value_out             => s_memout_rs1_value_out,
        rs2_addr_out              => s_memout_rs2_addr_out,
        rs2_value_out             => s_memout_rs2_value_out,
        pipe_writeback_enable_out => s_memout_pipe_writeback_enable_out,   
        pipe_writeback_addr_out   => s_memout_pipe_writeback_addr_out,
        pipe_writeback_value_out  => s_memout_pipe_writeback_value_out
    );

    -- 5. OLED Controller Integration
    OledControllerEntity: entity work.oled_controller
    port map(
        clk        => clock,
        rst        => reset,
        cmd_data   => s_oled_cmd_data,
        oled_sdin  => oled_sdin,
        oled_sclk  => oled_sclk,
        oled_dc    => oled_dc,
        oled_res   => oled_res,
        oled_vbat  => oled_vbat,
        oled_vdd   => oled_vdd
    );

end architecture structural;