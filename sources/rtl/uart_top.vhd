library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_top is
    generic(
        SYNTHESIS   : boolean                       := true;
        BAUD_RATE   : integer                       := 115200;
        CLK_FREQ    : integer                       := 100_000_000;
        RAM_WIDTH   : integer                       := 8;
        RAM_DEPTH   : integer                       := 256
    );
    port (
        clk_in          : in  std_logic;
        sw              : in  std_logic_vector(1 downto 0);
        
        btn             : in  std_logic_vector(1 downto 0);
        ck_io2          : out std_logic;
        ck_io1          : in  std_logic;
        ck_io0          : out std_logic;
        led             : out std_logic_vector(3 downto 0);

        ck_io6          : out std_logic;
        ck_io7          : out std_logic;
        ck_io8          : out std_logic;
        ck_io9          : out std_logic;
        ck_io10         : out std_logic;
        ck_io11         : out std_logic;
        ck_io12         : out std_logic;
        ck_io13         : out std_logic
    );
end entity;

architecture rtl of uart_top is

    signal clk                  : std_logic;
    signal reset_in             : std_logic;
    signal tx                   : std_logic;
    signal rx                   : std_logic;
    
    signal data_check           : std_logic;
    signal process_done         : std_logic;
    
    signal btn_prev             : std_logic;
    signal bounce_cnt           : unsigned(7 downto 0);
    signal bounce_done_btn0     : std_logic;
    signal bounce_done_btn1     : std_logic;
    signal selected_cmd         : std_logic_vector(1 downto 0);

    signal tx_byte              : std_logic_vector(7 downto 0);
    
    signal rx_ready             : std_logic;
    signal tx_start             : std_logic;
    signal tx_busy              : std_logic;
    signal tx_bin               : std_logic;
    
    signal rx_test              : std_logic;

    signal data_in_ram_a        : std_logic_vector(7 downto 0);
    signal data_out_ram_a       : std_logic_vector(7 downto 0);
    signal ce_ram_a             : std_logic;
    signal we_ram_a             : std_logic;
    signal addr_ram_a           : std_logic_vector(7 downto 0);

    signal data_in_ram_b        : std_logic_vector(7 downto 0);
    signal data_out_ram_b       : std_logic_vector(7 downto 0);
    signal ce_ram_b             : std_logic;
    signal we_ram_b             : std_logic;
    signal addr_ram_b           : std_logic_vector(7 downto 0);
    
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
    ck_io2   <= '1';

    ck_io6   <= data_out_ram_b(0);
    ck_io7   <= data_out_ram_b(1);
    ck_io8   <= data_out_ram_b(2);
    ck_io9   <= data_out_ram_b(3);
    ck_io10  <= data_out_ram_b(4);
    ck_io11  <= data_out_ram_b(5);
    ck_io12  <= data_out_ram_b(6);
    ck_io13  <= data_out_ram_b(7);
    
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
            dout          => data_in_ram_a
        );

    rx_bram_ctrl : entity work.dma_rx_bram
        port map (
            clk         => clk,
            ce          => ce_ram_a,
            we          => we_ram_a,
            addr        => addr_ram_a,
            ready       => rx_ready
        );

    bram_inst : entity work.dp_ram
        generic map (
            RAM_WIDTH => RAM_WIDTH,
            RAM_DEPTH => RAM_DEPTH
        )
        port map (
            douta => data_out_ram_a,
            doutb => data_out_ram_b,
            addra => addr_ram_a,
            addrb => addr_ram_b,
            dina  => data_in_ram_a,
            dinb  => data_in_ram_b,
            clka  => clk,
            wea   => we_ram_a,
            web   => we_ram_b,
            ena   => ce_ram_a,
            enb   => ce_ram_b
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
