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
    0   => x"00f00513", -- addi x10, x0, 15
    1   => x"00000013", -- NOP
    2   => x"00000013", -- NOP
    3   => x"00000013", -- NOP
    4   => x"00000013", -- NOP
    5   => x"00000013", -- NOP
    6   => x"01051513", -- slli x10, x10, 16      (x10 = 0x000F0000)
    7   => x"00000013", -- NOP
    8   => x"00000013", -- NOP
    9   => x"00000013", -- NOP
    10  => x"00000013", -- NOP
    11  => x"00000013", -- NOP
    12  => x"00200293", -- addi x5, x0, 2   (X=2)
    13  => x"00000013", -- NOP
    14  => x"00000013", -- NOP
    15  => x"00000013", -- NOP
    16  => x"00000013", -- NOP
    17  => x"00000013", -- NOP
    18  => x"00200313", -- addi x6, x0, 2   (Y=2)
    19  => x"00000013", -- NOP
    20  => x"00000013", -- NOP
    21  => x"00000013", -- NOP
    22  => x"00000013", -- NOP
    23  => x"00000013", -- NOP
    24  => x"00100593", -- addi x11, x0, 1   (+1 step)
    25  => x"00000013", -- NOP
    26  => x"00000013", -- NOP
    27  => x"00000013", -- NOP
    28  => x"00000013", -- NOP
    29  => x"00000013", -- NOP
    30  => x"fff00613", -- addi x12, x0, -1  (-1 step)
    31  => x"00000013", -- NOP
    32  => x"00000013", -- NOP
    33  => x"00000013", -- NOP
    34  => x"00000013", -- NOP
    35  => x"00000013", -- NOP
    36  => x"7d000493", -- addi x9, x0, 2000
    37  => x"00000013", -- NOP
    38  => x"00000013", -- NOP
    39  => x"00000013", -- NOP
    40  => x"00000013", -- NOP
    41  => x"00000013", -- NOP
    42  => x"7d048493", -- addi x9, x9, 2000
    43  => x"00000013", -- NOP
    44  => x"00000013", -- NOP
    45  => x"00000013", -- NOP
    46  => x"00000013", -- NOP
    47  => x"00000013", -- NOP
    48  => x"7d048493", -- addi x9, x9, 2000
    49  => x"00000013", -- NOP
    50  => x"00000013", -- NOP
    51  => x"00000013", -- NOP
    52  => x"00000013", -- NOP
    53  => x"00000013", -- NOP
    54  => x"7d048493", -- addi x9, x9, 2000
    55  => x"00000013", -- NOP
    56  => x"00000013", -- NOP
    57  => x"00000013", -- NOP
    58  => x"00000013", -- NOP
    59  => x"00000013", -- NOP
    60  => x"7d048493", -- addi x9, x9, 2000
    61  => x"00000013", -- NOP
    62  => x"00000013", -- NOP
    63  => x"00000013", -- NOP
    64  => x"00000013", -- NOP
    65  => x"00000013", -- NOP
    66  => x"7d048493", -- addi x9, x9, 2000
    67  => x"00000013", -- NOP
    68  => x"00000013", -- NOP
    69  => x"00000013", -- NOP
    70  => x"00000013", -- NOP
    71  => x"00000013", -- NOP
    72  => x"7d048493", -- addi x9, x9, 2000
    73  => x"00000013", -- NOP
    74  => x"00000013", -- NOP
    75  => x"00000013", -- NOP
    76  => x"00000013", -- NOP
    77  => x"00000013", -- NOP
    78  => x"7d048493", -- addi x9, x9, 2000
    79  => x"00000013", -- NOP
    80  => x"00000013", -- NOP
    81  => x"00000013", -- NOP
    82  => x"00000013", -- NOP
    83  => x"00000013", -- NOP
    84  => x"7d048493", -- addi x9, x9, 2000
    85  => x"00000013", -- NOP
    86  => x"00000013", -- NOP
    87  => x"00000013", -- NOP
    88  => x"00000013", -- NOP
    89  => x"00000013", -- NOP
    90  => x"7d048493", -- addi x9, x9, 2000
    91  => x"00000013", -- NOP
    92  => x"00000013", -- NOP
    93  => x"00000013", -- NOP
    94  => x"00000013", -- NOP
    95  => x"00000013", -- NOP
    96  => x"7d048493", -- addi x9, x9, 2000
    97  => x"00000013", -- NOP
    98  => x"00000013", -- NOP
    99  => x"00000013", -- NOP
    100 => x"00000013", -- NOP
    101 => x"00000013", -- NOP
    102 => x"7d048493", -- addi x9, x9, 2000
    103 => x"00000013", -- NOP
    104 => x"00000013", -- NOP
    105 => x"00000013", -- NOP
    106 => x"00000013", -- NOP
    107 => x"00000013", -- NOP
    108 => x"7d048493", -- addi x9, x9, 2000
    109 => x"00000013", -- NOP
    110 => x"00000013", -- NOP
    111 => x"00000013", -- NOP
    112 => x"00000013", -- NOP
    113 => x"00000013", -- NOP
    114 => x"7d048493", -- addi x9, x9, 2000
    115 => x"00000013", -- NOP
    116 => x"00000013", -- NOP
    117 => x"00000013", -- NOP
    118 => x"00000013", -- NOP
    119 => x"00000013", -- NOP
    120 => x"7d048493", -- addi x9, x9, 2000
    121 => x"00000013", -- NOP
    122 => x"00000013", -- NOP
    123 => x"00000013", -- NOP
    124 => x"00000013", -- NOP
    125 => x"00000013", -- NOP
    126 => x"7d048493", -- addi x9, x9, 2000
    127 => x"00000013", -- NOP
    128 => x"00000013", -- NOP
    129 => x"00000013", -- NOP
    130 => x"00000013", -- NOP
    131 => x"00000013", -- NOP
    132 => x"7d048493", -- addi x9, x9, 2000
    133 => x"00000013", -- NOP
    134 => x"00000013", -- NOP
    135 => x"00000013", -- NOP
    136 => x"00000013", -- NOP
    137 => x"00000013", -- NOP
    138 => x"7d048493", -- addi x9, x9, 2000
    139 => x"00000013", -- NOP
    140 => x"00000013", -- NOP
    141 => x"00000013", -- NOP
    142 => x"00000013", -- NOP
    143 => x"00000013", -- NOP
    144 => x"7d048493", -- addi x9, x9, 2000
    145 => x"00000013", -- NOP
    146 => x"00000013", -- NOP
    147 => x"00000013", -- NOP
    148 => x"00000013", -- NOP
    149 => x"00000013", -- NOP
    150 => x"7d048493", -- addi x9, x9, 2000
    151 => x"00000013", -- NOP
    152 => x"00000013", -- NOP
    153 => x"00000013", -- NOP
    154 => x"00000013", -- NOP
    155 => x"00000013", -- NOP
    156 => x"7d048493", -- addi x9, x9, 2000
    157 => x"00000013", -- NOP
    158 => x"00000013", -- NOP
    159 => x"00000013", -- NOP
    160 => x"00000013", -- NOP
    161 => x"00000013", -- NOP
    162 => x"7d048493", -- addi x9, x9, 2000
    163 => x"00000013", -- NOP
    164 => x"00000013", -- NOP
    165 => x"00000013", -- NOP
    166 => x"00000013", -- NOP
    167 => x"00000013", -- NOP
    168 => x"7d048493", -- addi x9, x9, 2000
    169 => x"00000013", -- NOP
    170 => x"00000013", -- NOP
    171 => x"00000013", -- NOP
    172 => x"00000013", -- NOP
    173 => x"00000013", -- NOP
    174 => x"7d048493", -- addi x9, x9, 2000
    175 => x"00000013", -- NOP
    176 => x"00000013", -- NOP
    177 => x"00000013", -- NOP
    178 => x"00000013", -- NOP
    179 => x"00000013", -- NOP
    180 => x"7d048493", -- addi x9, x9, 2000
    181 => x"00000013", -- NOP
    182 => x"00000013", -- NOP
    183 => x"00000013", -- NOP
    184 => x"00000013", -- NOP
    185 => x"00000013", -- NOP
    186 => x"7d048493", -- addi x9, x9, 2000
    187 => x"00000013", -- NOP
    188 => x"00000013", -- NOP
    189 => x"00000013", -- NOP
    190 => x"00000013", -- NOP
    191 => x"00000013", -- NOP
    192 => x"7d048493", -- addi x9, x9, 2000
    193 => x"00000013", -- NOP
    194 => x"00000013", -- NOP
    195 => x"00000013", -- NOP
    196 => x"00000013", -- NOP
    197 => x"00000013", -- NOP
    198 => x"7d048493", -- addi x9, x9, 2000
    199 => x"00000013", -- NOP
    200 => x"00000013", -- NOP
    201 => x"00000013", -- NOP
    202 => x"00000013", -- NOP
    203 => x"00000013", -- NOP
    204 => x"07800413", -- addi x8, x0, 120
    205 => x"00000013", -- NOP
    206 => x"00000013", -- NOP
    207 => x"00000013", -- NOP
    208 => x"00000013", -- NOP
    209 => x"00000013", -- NOP
    210 => x"00b282b3", -- x5 += delta (X)
    211 => x"00000013", -- NOP
    212 => x"00000013", -- NOP
    213 => x"00000013", -- NOP
    214 => x"00000013", -- NOP
    215 => x"00000013", -- NOP
    216 => x"00831393", -- x7 = Y << 8
    217 => x"00000013", -- NOP
    218 => x"00000013", -- NOP
    219 => x"00000013", -- NOP
    220 => x"00000013", -- NOP
    221 => x"00000013", -- NOP
    222 => x"0053e3b3", -- x7 = (Y<<8) | X
    223 => x"00000013", -- NOP
    224 => x"00000013", -- NOP
    225 => x"00000013", -- NOP
    226 => x"00000013", -- NOP
    227 => x"00000013", -- NOP
    228 => x"00752223", -- sw x7, 4(x10)   -- write cmd reg
    229 => x"00000013", -- NOP
    230 => x"00000013", -- NOP
    231 => x"00000013", -- NOP
    232 => x"00000013", -- NOP
    233 => x"00000013", -- NOP
    234 => x"00048693", -- x13 = x9  (load delay)
    235 => x"00000013", -- NOP
    236 => x"00000013", -- NOP
    237 => x"00000013", -- NOP
    238 => x"00000013", -- NOP
    239 => x"00000013", -- NOP
    240 => x"fff68693", -- x13 -= 1
    241 => x"00000013", -- NOP
    242 => x"00000013", -- NOP
    243 => x"fe069ae3", -- loop while x13 != 0
    244 => x"00000013", -- NOP
    245 => x"00000013", -- NOP
    246 => x"00000013", -- NOP
    247 => x"00000013", -- NOP
    248 => x"00000013", -- NOP
    249 => x"fff40413", -- x8 -= 1
    250 => x"00000013", -- NOP
    251 => x"00000013", -- NOP
    252 => x"f4041ce3", -- loop while x8 != 0
    253 => x"00000013", -- NOP
    254 => x"00000013", -- NOP
    255 => x"00000013", -- NOP
    256 => x"00000013", -- NOP
    257 => x"00000013", -- NOP
    258 => x"01800413", -- addi x8, x0, 24
    259 => x"00000013", -- NOP
    260 => x"00000013", -- NOP
    261 => x"00000013", -- NOP
    262 => x"00000013", -- NOP
    263 => x"00000013", -- NOP
    264 => x"00b30333", -- x6 += delta (Y)
    265 => x"00000013", -- NOP
    266 => x"00000013", -- NOP
    267 => x"00000013", -- NOP
    268 => x"00000013", -- NOP
    269 => x"00000013", -- NOP
    270 => x"00831393", -- x7 = Y << 8
    271 => x"00000013", -- NOP
    272 => x"00000013", -- NOP
    273 => x"00000013", -- NOP
    274 => x"00000013", -- NOP
    275 => x"00000013", -- NOP
    276 => x"0053e3b3", -- x7 = (Y<<8) | X
    277 => x"00000013", -- NOP
    278 => x"00000013", -- NOP
    279 => x"00000013", -- NOP
    280 => x"00000013", -- NOP
    281 => x"00000013", -- NOP
    282 => x"00752223", -- sw x7, 4(x10)   -- write cmd reg
    283 => x"00000013", -- NOP
    284 => x"00000013", -- NOP
    285 => x"00000013", -- NOP
    286 => x"00000013", -- NOP
    287 => x"00000013", -- NOP
    288 => x"00048693", -- x13 = x9  (load delay)
    289 => x"00000013", -- NOP
    290 => x"00000013", -- NOP
    291 => x"00000013", -- NOP
    292 => x"00000013", -- NOP
    293 => x"00000013", -- NOP
    294 => x"fff68693", -- x13 -= 1
    295 => x"00000013", -- NOP
    296 => x"00000013", -- NOP
    297 => x"fe069ae3", -- loop while x13 != 0
    298 => x"00000013", -- NOP
    299 => x"00000013", -- NOP
    300 => x"00000013", -- NOP
    301 => x"00000013", -- NOP
    302 => x"00000013", -- NOP
    303 => x"fff40413", -- x8 -= 1
    304 => x"00000013", -- NOP
    305 => x"00000013", -- NOP
    306 => x"f4041ce3", -- loop while x8 != 0
    307 => x"00000013", -- NOP
    308 => x"00000013", -- NOP
    309 => x"00000013", -- NOP
    310 => x"00000013", -- NOP
    311 => x"00000013", -- NOP
    312 => x"07800413", -- addi x8, x0, 120
    313 => x"00000013", -- NOP
    314 => x"00000013", -- NOP
    315 => x"00000013", -- NOP
    316 => x"00000013", -- NOP
    317 => x"00000013", -- NOP
    318 => x"00c282b3", -- x5 += delta (X)
    319 => x"00000013", -- NOP
    320 => x"00000013", -- NOP
    321 => x"00000013", -- NOP
    322 => x"00000013", -- NOP
    323 => x"00000013", -- NOP
    324 => x"00831393", -- x7 = Y << 8
    325 => x"00000013", -- NOP
    326 => x"00000013", -- NOP
    327 => x"00000013", -- NOP
    328 => x"00000013", -- NOP
    329 => x"00000013", -- NOP
    330 => x"0053e3b3", -- x7 = (Y<<8) | X
    331 => x"00000013", -- NOP
    332 => x"00000013", -- NOP
    333 => x"00000013", -- NOP
    334 => x"00000013", -- NOP
    335 => x"00000013", -- NOP
    336 => x"00752223", -- sw x7, 4(x10)   -- write cmd reg
    337 => x"00000013", -- NOP
    338 => x"00000013", -- NOP
    339 => x"00000013", -- NOP
    340 => x"00000013", -- NOP
    341 => x"00000013", -- NOP
    342 => x"00048693", -- x13 = x9  (load delay)
    343 => x"00000013", -- NOP
    344 => x"00000013", -- NOP
    345 => x"00000013", -- NOP
    346 => x"00000013", -- NOP
    347 => x"00000013", -- NOP
    348 => x"fff68693", -- x13 -= 1
    349 => x"00000013", -- NOP
    350 => x"00000013", -- NOP
    351 => x"fe069ae3", -- loop while x13 != 0
    352 => x"00000013", -- NOP
    353 => x"00000013", -- NOP
    354 => x"00000013", -- NOP
    355 => x"00000013", -- NOP
    356 => x"00000013", -- NOP
    357 => x"fff40413", -- x8 -= 1
    358 => x"00000013", -- NOP
    359 => x"00000013", -- NOP
    360 => x"f4041ce3", -- loop while x8 != 0
    361 => x"00000013", -- NOP
    362 => x"00000013", -- NOP
    363 => x"00000013", -- NOP
    364 => x"00000013", -- NOP
    365 => x"00000013", -- NOP
    366 => x"01800413", -- addi x8, x0, 24
    367 => x"00000013", -- NOP
    368 => x"00000013", -- NOP
    369 => x"00000013", -- NOP
    370 => x"00000013", -- NOP
    371 => x"00000013", -- NOP
    372 => x"00c30333", -- x6 += delta (Y)
    373 => x"00000013", -- NOP
    374 => x"00000013", -- NOP
    375 => x"00000013", -- NOP
    376 => x"00000013", -- NOP
    377 => x"00000013", -- NOP
    378 => x"00831393", -- x7 = Y << 8
    379 => x"00000013", -- NOP
    380 => x"00000013", -- NOP
    381 => x"00000013", -- NOP
    382 => x"00000013", -- NOP
    383 => x"00000013", -- NOP
    384 => x"0053e3b3", -- x7 = (Y<<8) | X
    385 => x"00000013", -- NOP
    386 => x"00000013", -- NOP
    387 => x"00000013", -- NOP
    388 => x"00000013", -- NOP
    389 => x"00000013", -- NOP
    390 => x"00752223", -- sw x7, 4(x10)   -- write cmd reg
    391 => x"00000013", -- NOP
    392 => x"00000013", -- NOP
    393 => x"00000013", -- NOP
    394 => x"00000013", -- NOP
    395 => x"00000013", -- NOP
    396 => x"00048693", -- x13 = x9  (load delay)
    397 => x"00000013", -- NOP
    398 => x"00000013", -- NOP
    399 => x"00000013", -- NOP
    400 => x"00000013", -- NOP
    401 => x"00000013", -- NOP
    402 => x"fff68693", -- x13 -= 1
    403 => x"00000013", -- NOP
    404 => x"00000013", -- NOP
    405 => x"fe069ae3", -- loop while x13 != 0
    406 => x"00000013", -- NOP
    407 => x"00000013", -- NOP
    408 => x"00000013", -- NOP
    409 => x"00000013", -- NOP
    410 => x"00000013", -- NOP
    411 => x"fff40413", -- x8 -= 1
    412 => x"00000013", -- NOP
    413 => x"00000013", -- NOP
    414 => x"f4041ce3", -- loop while x8 != 0
    415 => x"00000013", -- NOP
    416 => x"00000013", -- NOP
    417 => x"00000013", -- NOP
    418 => x"00000013", -- NOP
    419 => x"00000013", -- NOP
    420 => x"ca1ff06f", -- jump back to start of LEG1 to repeat the square path
    others => x"00000013" -- Fill remaining memory space with NOPs
);
    attribute ram_style : string;
    attribute ram_style of bram : signal is "block";
    
    signal s_mem_addr: std_logic_vector(10 downto 0) := (others => '0');
    signal s_curr_instruction: std_logic_vector(31 downto 0) := (others => '0');
    signal s_pc: std_logic_vector(31 downto 0) := (others => '0');
    
    signal s_branch_prediction: std_logic := '0';
    signal s_branch_prediction_offset: std_logic_vector(31 downto 0) := (others => '0');
    signal s_branch_pending: std_logic_vector(1 downto 0) := (others => '0');
    signal s_jump_pending: std_logic_vector(1 downto 0) := (others => '0');
    signal s_jump_jal_offset: std_logic_vector(31 downto 0) := (others => '0');
    
    signal s_saved_branch_pc: std_logic_vector(31 downto 0) := (others => '0');
    signal s_saved_branch_prediction: std_logic := '0';
begin
    
    s_mem_addr <= s_pc(12 downto 2);                                
    instructionFetch: process(clock, reset)
        variable v_pc: std_logic_vector(31 downto 0) := (others => '0');
        variable v_next_pc: std_logic_vector(31 downto 0) := (others => '0');
        variable v_curr_instruction: std_logic_vector(31 downto 0) := (others => '0');
        variable v_curr_opcode: std_logic_vector(6 downto 0) := (others => '0');
        variable v_immediate_13bits: std_logic_vector(12 downto 0) := (others => '0');
        variable v_immediate_21bits: std_logic_vector(20 downto 0) := (others => '0');
        variable v_branch_prediction_taken: std_logic := '0';
        variable v_mask_instruction: std_logic := '0';
        variable v_pc_offset: std_logic_vector(31 downto 0) := (others => '0');
        variable v_saved_branch_pc: std_logic_vector(31 downto 0) := (others => '0');
        variable v_saved_branch_prediction: std_logic := '0';
    begin
        if reset = '1' then
            s_curr_instruction <= (others => '0');
            s_pc <= (others => '0');
            curr_instruction <= (others => '0');
            reg_pc <= (others => '0');
            s_jump_pending <= (others => '0');
            s_jump_jal_offset <= (others => '0');
            s_branch_prediction <= '0';
            s_saved_branch_pc <= (others => '0');
            s_saved_branch_prediction <= '0';
        elsif rising_edge(clock) then
            if enable_fetch = '1' then
                v_pc_offset := (others => '0');
                v_pc := s_pc;
                v_saved_branch_pc := s_saved_branch_pc;
                v_saved_branch_prediction := s_saved_branch_prediction;

                case (s_jump_pending) is
                    when "01" =>
                        s_jump_pending <= "00";
                        v_pc_offset := std_logic_vector(signed(s_jump_jal_offset) - to_signed(4, 32));
                        v_pc := s_pc;
                    when "11" =>
                        s_jump_pending <= "10";
                        v_mask_instruction := '1';
                    when "10" =>
                        s_jump_pending <= "00";
                        v_mask_instruction := '0';
                        v_pc_offset := (others => '0');
                        v_pc := jump_jalr_pc;                       
                    when others =>
                        null;
                end case;

                case (s_branch_pending) is
                    when "11" =>                                    
                        if v_saved_branch_prediction = '1' then           
                            v_pc_offset := std_logic_vector(signed(s_branch_prediction_offset) - to_signed(4, 32));
                        elsif v_saved_branch_prediction = '0' then        
                            v_pc := s_pc;                           
                        end if;
                        s_branch_pending <= "10";                   
                    when "10" =>
                        s_branch_pending <= "00";
                        if branch_misprediction = '1' then          
                            if v_saved_branch_prediction = '1' then
                                v_pc := std_logic_vector(signed(v_saved_branch_pc) + to_signed(4, 32));
                            else
                                v_pc := std_logic_vector(signed(v_saved_branch_pc) + signed(s_branch_prediction_offset));
                            end if;
                        end if;
                    when others =>
                        null; 
                end case;

                if not (s_branch_pending = "10" and branch_misprediction = '1') then
                    v_pc := std_logic_vector(signed(v_pc) + signed(v_pc_offset));
                end if;

                v_next_pc := std_logic_vector(signed(v_pc) + to_signed(4, 32));
                v_curr_instruction := bram(to_integer(unsigned(v_pc(12 downto 2))));
                v_curr_opcode := v_curr_instruction(6 downto 0);
                
                if v_mask_instruction = '1' then
                    v_curr_instruction(6 downto 0) := "0000000";    
                end if;

                case(v_curr_opcode) is
                    when "1101111" => 
                        v_immediate_21bits := v_curr_instruction(31) & 
                            v_curr_instruction(19 downto 12) &      
                            v_curr_instruction(20) &                
                            v_curr_instruction(30 downto 21) &      
                            '0';                                    
                        s_jump_jal_offset <= std_logic_vector(resize(signed(v_immediate_21bits), 32));
                        s_jump_pending <= "01";
                    when "1100111" => 
                        s_jump_pending <= "11";
                    when "1100011" => 
                        s_branch_pending <= "11";
                        v_branch_prediction_taken := v_curr_instruction(31);  
                        v_saved_branch_pc := v_pc; 
                        v_saved_branch_prediction := v_branch_prediction_taken;
                        
                        if v_branch_prediction_taken = '1' then                      
                            v_immediate_13bits := v_curr_instruction(31) & 
                                v_curr_instruction(7) &                 
                                v_curr_instruction(30 downto 25) &      
                                v_curr_instruction(11 downto 8) &       
                                '0';                                    
                            s_branch_prediction_offset <= std_logic_vector(resize(signed(v_immediate_13bits), 32));
                        end if;
                    when others =>
                        null;
                end case;

                s_pc <= v_next_pc;
                s_branch_prediction <= v_branch_prediction_taken;
                s_saved_branch_pc <= v_saved_branch_pc;
                s_saved_branch_prediction <= v_saved_branch_prediction;
                branch_prediction <= v_branch_prediction_taken;
                curr_instruction <= v_curr_instruction;
                reg_pc <= v_next_pc;
            end if;
        end if;
    end process;
end architecture;