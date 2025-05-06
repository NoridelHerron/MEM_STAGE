----------------------------------------------------------------------------------
--  Title       : MEM_STAGE.vhd
--  Description : Memory stage of a 5-stage pipelined RISC-V processor.
--                Interfaces with DATA_MEM to handle load/store instructions.
--                Converts ALU result into memory address and performs memory
--                read/write operations based on control signals.
--
--  Author      : Noridel Herron
--  Date        : May 6, 2025
--  Dependencies: DATA_MEM.vhd
--
--  Notes       : 
--    - Assumes word-aligned addressing (ALU result shifted by 2 bits).
--    - mem_read and mem_write should be mutually exclusive.
--    - Passes read data to the WB stage via 'mem_out'.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MEM_STAGE is
    Port ( clk           : in  std_logic;
           alu_result    : in  std_logic_vector(31 downto 0); -- Byte address from ALU (EX stage), used for memory read/write
           write_data    : in  std_logic_vector(31 downto 0); -- for store instruction
           mem_out       : out std_logic_vector(31 downto 0); -- for load instruction
    
           -- Pass-through control & destination signals
           reg_write_in  : in  std_logic;
           mem_read_in   : in  std_logic;
           mem_write_in  : in  std_logic;
           rd_in         : in  std_logic_vector(4 downto 0);
    
           -- Output to WB stage
           reg_write_out : out std_logic;
           mem_read_out : out std_logic;
           mem_write_out : out std_logic;
           rd_out        : out std_logic_vector(4 downto 0)
         );
end MEM_STAGE;

architecture behavior of MEM_STAGE is
   
    component DATA_MEM
        Port (
            clk        : in  std_logic;
            mem_read   : in  std_logic;
            mem_write  : in  std_logic;
            address    : in  std_logic_vector(9 downto 0);
            write_data : in  std_logic_vector(31 downto 0);
            read_data  : out std_logic_vector(31 downto 0)
        );
    end component;

    signal mem_address : std_logic_vector(9 downto 0);

begin
    mem_address <= alu_result(11 downto 2); -- word-aligned

    -- Instantiate memory
    memory_block: DATA_MEM port map (clk, mem_read_in, mem_write_in, mem_address, write_data, mem_out);

    -- Pass-through control and destination signals to WB 
    reg_write_out <= reg_write_in;
    rd_out        <= rd_in;
    mem_read_out <= mem_read_in;
    mem_write_out <= mem_write_in;
end behavior;
