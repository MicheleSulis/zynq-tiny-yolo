library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_gray_scale_converter is
end entity;

architecture behavioural of tb_gray_scale_converter is

    signal aclk          : std_ulogic := '0';
    signal aresetn       : std_ulogic := '0';
    
    signal s_axis_tvalid : std_ulogic := '0';
    signal s_axis_tready : std_ulogic;
    signal s_axis_tlast  : std_ulogic := '0';
    signal s_axis_tdata  : std_ulogic_vector(31 downto 0) := (others => '0');
    signal s_axis_tkeep  : std_ulogic_vector(3 downto 0) := "0111";

    signal m_axis_tvalid : std_ulogic;
    signal m_axis_tready : std_ulogic := '1';
    signal m_axis_tlast  : std_ulogic;
    signal m_axis_tdata  : std_ulogic_vector(7 downto 0);
    signal m_axis_tkeep  : std_ulogic_vector(0 downto 0);

    signal sim_done : boolean := false;


    function gray_word(
        pixel : std_ulogic_vector(31 downto 0)
    ) return std_ulogic_vector is

        variable r, g, b : unsigned(7 downto 0);
        variable sum     : unsigned(9 downto 0);
        variable gray    : unsigned(9 downto 0);

        variable result  : std_ulogic_vector(31 downto 0)
                         := (others => '0');
    begin

        r := unsigned(pixel(23 downto 16));
        g := unsigned(pixel(15 downto 8));
        b := unsigned(pixel(7 downto 0));

        sum := resize(r, 10)
             + resize(g, 10)
             + resize(b, 10);

        gray := sum / 3;

        result(9 downto 0) := std_ulogic_vector(gray);

        return result;

    end function;

begin

    dut : entity work.converter(behavioural)
        port map (
            aclk          => aclk,
            aresetn       => aresetn,

            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tkeep  => s_axis_tkeep,

            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast  => m_axis_tlast,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tkeep  => m_axis_tkeep
        );


    -- 50 MHz clock
    clock : process
    begin
        while not sim_done loop
            aclk <= '0';
            wait for 10 ns;

            aclk <= '1';
            wait for 10 ns;
        end loop;

        wait;
    end process;


    stimulus : process
        constant A : std_ulogic_vector(31 downto 0) := x"00FF0000";
        constant B : std_ulogic_vector(31 downto 0) := x"00010203";
        constant C : std_ulogic_vector(31 downto 0) := x"00306090";
    begin
        wait until rising_edge(aclk);
        wait for 1 ns;
    
        assert m_axis_tvalid = '0'
            report "Reset: m_axis_tvalid dovrebbe essere 0"
            severity error;
    
        assert s_axis_tready = '0'
            report "Reset: s_axis_tready dovrebbe essere 0"
            severity error;
        
        wait until falling_edge(aclk);
        aresetn <= '1';
    
        ----------------------------------------------------------------
        -- A: primo beat
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tvalid <= '1';
        s_axis_tdata  <= A;
        s_axis_tlast  <= '0';
        m_axis_tready <= '1';

        wait until rising_edge(aclk);
        wait for 1 ns;

        assert m_axis_tvalid = '1'
            report "A: m_axis_tvalid non valido"
            severity error;

        assert m_axis_tdata = gray_word(A)
            report "A: grayscale errato"
            severity error;


        ----------------------------------------------------------------
        -- B: beat successivo, nessuno stall
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tdata <= B;
        s_axis_tlast <= '1';

        wait until rising_edge(aclk);
        wait for 1 ns;

        assert m_axis_tdata = gray_word(B)
            report "B: grayscale errato"
            severity error;

        assert m_axis_tlast = '1'
            report "B: TLAST errato"
            severity error;


        ----------------------------------------------------------------
        -- C arriva, ma il consumer blocca READY.
        -- B deve rimanere congelato.
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tdata  <= C;
        s_axis_tlast  <= '0';
        m_axis_tready <= '0';

        wait for 1 ns;

        assert s_axis_tready = '0'
            report "Backpressure: s_axis_tready dovrebbe essere 0"
            severity error;

        wait until rising_edge(aclk);
        wait for 1 ns;

        assert m_axis_tdata = gray_word(B)
            report "Backpressure: B non e' rimasto memorizzato"
            severity error;

        assert m_axis_tlast = '1'
            report "Backpressure: TLAST non e' rimasto memorizzato"
            severity error;


        ----------------------------------------------------------------
        -- Manteniamo lo stall per un altro clock
        ----------------------------------------------------------------

        wait until rising_edge(aclk);
        wait for 1 ns;

        assert m_axis_tdata = gray_word(B)
            report "Backpressure: dato modificato durante lo stall"
            severity error;


        ----------------------------------------------------------------
        -- Il consumer torna READY.
        -- C era rimasto stabile e ora deve essere acquisito.
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        m_axis_tready <= '1';

        wait for 1 ns;

        assert s_axis_tready = '1'
            report "Release backpressure: s_axis_tready dovrebbe essere 1"
            severity error;

        wait until rising_edge(aclk);
        wait for 1 ns;

        assert m_axis_tdata = gray_word(C)
            report "C: grayscale errato dopo backpressure"
            severity error;


        ----------------------------------------------------------------
        -- Nessun nuovo dato
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tvalid <= '0';

        wait until rising_edge(aclk);
        wait for 1 ns;

        assert m_axis_tvalid = '0'
            report "m_axis_tvalid dovrebbe essere 0"
            severity error;


        report "TEST COMPLETATO" severity note;

        sim_done <= true;
        wait;

    end process;

end architecture;
