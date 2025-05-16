library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
    generic (
        count_to_lock : integer := 15
    );
    port (
        clk             : in  std_logic;
        btn             : in  std_logic;
        sig             : out std_logic
    );
end entity;

architecture rtl of debounce is

    signal bounce_cnt       : unsigned(count_to_lock downto 0);
    type state_type is (idle, bounce, zero, unbounce);
    signal state           : state_type := idle;

begin
process(clk)
    begin
        if rising_edge(clk) then
            case state is
                when idle =>
                    sig <= '0';
                    bounce_cnt <= (others => '0');
                    if btn = '1' then
                        state <= bounce;
                    end if;
                when bounce =>
                    if bounce_cnt(count_to_lock) /= '1' then
                        bounce_cnt <= bounce_cnt + 1;
                    else
                        sig <= '1';
                        state <= zero;
                    end if;
                when zero => 
                    bounce_cnt <= (others => '0');
                    sig <= '0';
                    if btn = '0' then
                        state <= unbounce;
                    end if;

                when unbounce =>
                    if bounce_cnt(count_to_lock) /= '1' then
                        bounce_cnt <= bounce_cnt + 1;
                    else
                        bounce_cnt <= (others => '0');
                        state <= idle;
                    end if;
            end case;
        end if;
    end process;
end architecture;