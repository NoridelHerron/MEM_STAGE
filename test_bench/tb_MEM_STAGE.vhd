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
        Port (
           clk           : in  std_logic;
           alu_result    : in  std_logic_vector(31 downto 0);
           write_data    : in  std_logic_vector(31 downto 0);
           op_in         : in  std_logic_vector(2 downto 0);
           rd_in         : in  std_logic_vector(4 downto 0);
           mem_out       : out std_logic_vector(31 downto 0);
           reg_write_out : out std_logic;
           rd_out        : out std_logic_vector(4 downto 0)
        );
    end component;

    signal clk           : std_logic := '0';
    signal alu_result    : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_out       : std_logic_vector(31 downto 0);
    signal op_in         : std_logic_vector(2 downto 0) := (others => '0');
    signal reg_write_out : std_logic;
    signal rd_in         : std_logic_vector(4 downto 0) := (others => '0');
    signal rd_out        : std_logic_vector(4 downto 0);
    type mem_array is array(0 to 1023) of std_logic_vector(31 downto 0);
    signal expected_memory : mem_array := (others => (others => '0'));

begin

    clk_process : process
    begin
        while now < 2 ms loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
        wait;
    end process;

    uut: MEM_STAGE port map (
        clk => clk,
        alu_result => alu_result,
        write_data => write_data,
        op_in => op_in,
        rd_in => rd_in,
        mem_out => mem_out,
        reg_write_out => reg_write_out,
        rd_out => rd_out
    );

    stimulus : process
        variable seed1, seed2 : positive := 42;
        variable rand_real    : real;
        variable rand_addr    : integer;
        variable rand_data    : std_logic_vector(31 downto 0);
        variable rand_rd      : std_logic_vector(4 downto 0);
        variable is_load      : boolean;
        variable NUM_TESTS    : integer := 5000;
        variable passed, failed : integer := 0;
    begin
        wait for 20 ns;

        for i in 0 to NUM_TESTS - 1 loop
            uniform(seed1, seed2, rand_real);
            rand_addr := integer(rand_real * 1024.0) mod 1024;

            for b in 0 to 31 loop
                uniform(seed1, seed2, rand_real);
                if rand_real < 0.5 then
                    rand_data(b) := '0';
                else
                    rand_data(b) := '1';
                end if;
            end loop;

            uniform(seed1, seed2, rand_real);
            rand_rd := std_logic_vector(to_unsigned(integer(rand_real * 32.0), 5));

            uniform(seed1, seed2, rand_real);
            is_load := rand_real > 0.5;

            alu_result <= std_logic_vector(to_unsigned(rand_addr * 4, 32));
            write_data <= rand_data;
            rd_in <= rand_rd;

            if is_load then
                op_in <= "010";
            else
                op_in <= "011";
            end if;

            wait for 10 ns;

            if not is_load then
                expected_memory(rand_addr) <= rand_data;
            end if;

            wait for 10 ns;

            if is_load then
                if mem_out = expected_memory(rand_addr) and reg_write_out = '1' and rd_out = rand_rd then
                    passed := passed + 1;
                else
                    report "FAILED on LOAD test #" & integer'image(i)
                        & " | mem_out = " & to_hexstring(mem_out)
                        & ", expected = " & to_hexstring(expected_memory(rand_addr))
                        & ", reg_write = " & std_logic'image(reg_write_out)
                        & ", rd = " & integer'image(to_integer(unsigned(rd_out)))
                        severity error;
                    failed := failed + 1;
                end if;
            else
                if reg_write_out = '0' and rd_out = rand_rd then
                    passed := passed + 1;
                else
                    report "FAILED on STORE test #" & integer'image(i)
                        & " | reg_write = " & std_logic'image(reg_write_out)
                        & ", rd = " & integer'image(to_integer(unsigned(rd_out)))
                        severity error;
                    failed := failed + 1;
                end if;
            end if;
        end loop;

        report "MEM_STAGE TESTING COMPLETE: " & integer'image(passed) & " passed, " & integer'image(failed) & " failed";
        std.env.stop;
    end process;

    watchdog : process
    begin
        wait for 300000 ns;
        report "TIMEOUT ERROR: Testbench ran too long" severity failure;
    end process;

end sim;
