library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_top is
    generic(
        SYNTHESIS   : boolean                       := true;
        BAUD_RATE   : integer                       := 115200;
        CLK_FREQ    : integer                       := 100_000_000
    );
    port (
        clk_in          : in  std_logic;
        sw              : in  std_logic_vector(1 downto 0);
        
        -- UART RX
        ck_io1          : in  std_logic;
        ce_ram_b        : out std_logic;   
        we_ram_b        : out std_logic;
        addr_ram_b      : out std_logic_vector(31 downto 0);
        data_in_ram_b   : out std_logic_vector(7 downto 0);

        -- UART TX
        ck_io0          : out std_logic;
        btn             : in  std_logic_vector(1 downto 0);
        led             : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of uart_top is

    signal clk                  : std_logic;
    signal reset_in             : std_logic;
    signal tx                   : std_logic;
    signal rx                   : std_logic;
    
    signal data_check           : std_logic;
    signal process_done         : std_logic;

    signal bounce_done_btn0     : std_logic;
    signal bounce_done_btn1     : std_logic;
    signal selected_cmd         : std_logic_vector(1 downto 0);

    signal tx_byte              : std_logic_vector(7 downto 0);
    signal rx_ready             : std_logic;
    signal tx_start             : std_logic;
    signal tx_busy              : std_logic;
    
    type state_type is (idle, s_0);
    signal state       : state_type := idle;
    type switcher_type is (s_0, s_1, s_2, s_3);
    signal switcher    : switcher_type := s_0;

    component clk_wiz_0 is
        port
        (
            reset       : in std_logic;
            clk_in1     : in std_logic;
            clk_out1    : out std_logic
        );
    end component;

begin

    reset_in <= sw(0);
    ck_io0   <= tx;
    rx       <= ck_io1;
    
    --Send packet
    process(clk)
    begin
    case state is
        when idle =>
            data_check <= '0';
            if bounce_done_btn0 = '1' then
                state <= s_0;
            end if;
            
        when s_0 =>
            data_check <= '1';
            if process_done = '1' then
                data_check <= '0';
                state <= idle;
            end if;

        when others =>
            state <= idle;
        end case;
    end process;

    --Switch mode
    process(clk, reset_in)
    begin
        if reset_in = '1' then
            switcher <= s_0;
        elsif rising_edge(clk) then
            if bounce_done_btn1 = '1' then
                case switcher is
                    when s_0 => switcher <= s_1;
                    when s_1 => switcher <= s_2;
                    when s_2 => switcher <= s_3;
                    when s_3 => switcher <= s_0;
                    when others => switcher <= s_0;
                end case;
            end if;
        end if;
    end process;

    process(state)
    begin
        led <= (others => '0');
        case switcher is
            when s_0 =>
                led <= "0001";
                selected_cmd <= "00";

            when s_1 =>
                led <= "0010";
                selected_cmd <= "01";

            when s_2 =>
                led <= "0100";
                selected_cmd <= "10";

            when s_3 =>
                led <= "1000";
                selected_cmd <= "11";
                
            when others =>
            led <= "0000";
            selected_cmd <= "00";

        end case;
    end process;
    
    debouncer_btn0 : entity work.debounce
        port map (
            clk => clk,
            btn => btn(0),
            sig => bounce_done_btn0
        );

    debouncer_btn1 : entity work.debounce
        port map (
            clk => clk,
            btn => btn(1),
            sig => bounce_done_btn1
        );

    rx_inst : entity work.uart_rx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk           => clk,
            reset         => reset_in,
            rx            => rx,
            ready         => rx_ready,
            dout          => data_in_ram_b
        );

    rx_bram_ctrl : entity work.dma_rx_bram
        port map (
            clk         => clk,
            ce          => ce_ram_b,
            we          => we_ram_b,
            addr        => addr_ram_b,
            ready       => rx_ready
        );

    tx_command_create : entity work.tx_command_create
        port map (
            clk             => clk,
            dout            => tx_byte,
            data_check      => data_check,
            process_done    => process_done,
            selected_cmd    => selected_cmd,
            tx_start        => tx_start,
            tx_busy         => tx_busy
        );


    tx_inst : entity work.uart_tx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk         => clk,
            reset       => reset_in,
            tx_start    => tx_start,
            din         => tx_byte,
            tx          => tx,
            tx_busy     => tx_busy
        );

    clock_gen_block : if SYNTHESIS = true generate
        clock_genegate: clk_wiz_0
            port map (
                reset       => reset_in,
                clk_in1     => clk_in,
                clk_out1    => clk
            );
    end generate clock_gen_block;

    no_clock_gen_block : if SYNTHESIS = false generate
        clk <= clk_in;
    end generate no_clock_gen_block;

end architecture;
