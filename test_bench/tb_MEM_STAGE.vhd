----------------------------------------------------------------------------------
--  Author      : Noridel Herron
--  Description : Testbench for MEM_STAGE using uniform-based randomization.
--                Tests 5000 randomized store/load operations with memory and
--                verifies reg_write and rd signal pass-through.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use IEEE.MATH_REAL.ALL;

-- Customized package (reusable function)
library work;
use work.reusable_function.all;

entity tb_MEM_STAGE is
end tb_MEM_STAGE;

architecture sim of tb_MEM_STAGE is

    component MEM_STAGE
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
           mem_read_out  : out std_logic;
           mem_write_out : out std_logic;
           rd_out        : out std_logic_vector(4 downto 0)
         );
    end component;

    signal clk           : std_logic := '0';
    signal alu_result    : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_out       : std_logic_vector(31 downto 0);
    signal reg_write_in  : std_logic := '0';
    signal mem_read_in   : std_logic := '0';
    signal mem_write_in  : std_logic := '0';
    signal rd_in         : std_logic_vector(4 downto 0) := (others => '0');
    signal reg_write_out : std_logic;
    signal mem_write_out : std_logic;
    signal mem_read_out  : std_logic;
    signal rd_out        : std_logic_vector(4 downto 0);
    type mem_array is array(0 to 1023) of std_logic_vector(31 downto 0); -- array declaration
    signal expected_memory : mem_array := (others => (others => '0'));

    constant NUM_TESTS : integer := 5000; -- number of test

begin

    -- Clock generator
    clk_process : process
    begin
        while now < 2 ms loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
        wait;
    end process;

    -- UNIT UNDER TEST
    uut: MEM_STAGE port map (clk, alu_result, write_data, mem_out, reg_write_in, mem_read_in, mem_write_in, rd_in, 
                             reg_write_out, mem_read_out, mem_write_out, rd_out );

    -- Stimulus process with uniform randomization
    stimulus : process
        -- variable for randomly generated value
        variable seed1, seed2   : positive := 42;
        variable rand_real      : real;
        variable rand_addr      : integer;
        variable rand_data      : std_logic_vector(31 downto 0);
        variable rand_rd        : std_logic_vector(4 downto 0);
        variable rand_write     : std_logic;   
        -- variable to keep track the pass/fail test
        variable passed, failed : integer := 0;
    begin
        wait for 20 ns;

        for i in 0 to NUM_TESTS - 1 loop
            -- Random address 0-1023
            uniform(seed1, seed2, rand_real);
            rand_addr := integer(rand_real * 1024.0) mod 1024; -- make sure rand_addr <= 1023

            -- Random 32-bit data
            for b in 0 to 31 loop
                uniform(seed1, seed2, rand_real);
                if rand_real < 0.5 then
                    rand_data(b) := '0';
                else
                    rand_data(b) := '1';
                end if;
            end loop;

            -- Random rd 0-31
            uniform(seed1, seed2, rand_real);
            rand_rd := std_logic_vector(to_unsigned(integer(rand_real * 32.0), 5));

            -- Random reg_write
            uniform(seed1, seed2, rand_real);
            if rand_real < 0.5 then
                rand_write := '0';
            else
                rand_write := '1';
            end if;

            -- WRITE PHASE
            alu_result    <= std_logic_vector(to_unsigned(rand_addr * 4, 32));          
            write_data    <= rand_data;
            
            -- if-else statement is an intentional bug
            --if i = 5 or i = 10 or i = 15 or i = 20  then
            --    write_data <= (others => 'Z'); -- (blue) high impedance
            --elsif i = 3 or i = 6 or i = 9 or i = 12  then
            --    write_data <= (others => 'X');  -- (red) force undefined
            --else
            --    write_data <= rand_data;
            --end if;      
                  
            reg_write_in  <= rand_write;
            mem_read_in   <= '0';
            mem_write_in  <= '1';
            rd_in         <= rand_rd;
            wait for 10 ns;
            
            expected_memory(rand_addr) <= rand_data;
            mem_write_in <= '0';
       
            -- READ PHASE
            alu_result    <= std_logic_vector(to_unsigned(rand_addr * 4, 32));                    
            write_data    <= (others => '0');
            mem_read_in   <= '1';
            wait for 10 ns;

            -- Compare output from MEM_STAGE with expected value
            if mem_out = expected_memory(rand_addr) and
               reg_write_out = rand_write and mem_read_in = mem_read_out
               and mem_write_in = mem_write_out and rd_out = rand_rd then
                passed := passed + 1;
            else
                report "FAILED on test #" & integer'image(i)
                    & " | mem_out = " & to_hexstring(mem_out)
                    & ", expected = " & to_hexstring(expected_memory(rand_addr))
                    & ", reg_write = " & std_logic'image(reg_write_out)
                    & ", rd = " & integer'image(to_integer(unsigned(rd_out)))
                    severity error;
                failed := failed + 1;
            end if;
    
            if mem_read_in = '1' and mem_write_in = '1' then
                report "ASSERTION FAILED on test #" & integer'image(i)
                    & " | Both mem_read_in and mem_write_in are HIGH - this is invalid."
                    severity failure;
                failed := failed + 1;
            end if;

            mem_read_in <= '0';
            wait for 10 ns;
        end loop;

        report "MEM_STAGE TESTING COMPLETE: " & integer'image(passed) & " passed, " & integer'image(failed) & " failed";
        wait;
    end process;
    
end sim;