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
    signal s_axis_tdata  : std_ulogic_vector(31 downto 0) := (others => '0');
    signal s_axis_tkeep  : std_ulogic_vector( 0 downto 0);
    signal s_axis_tlast  : std_ulogic;
    
    signal m_axis_tvalid : std_ulogic;
    signal m_axis_tready : std_ulogic := '1';
    signal m_axis_tdata  : std_ulogic_vector(7 downto 0);
    signal m_axis_tkeep  : std_ulogic_vector(0 downto 0);
    signal m_axis_tlast  : std_ulogic;

    signal sim_done : boolean := false;

begin

    dut : entity work.converter(fifo_behav)
        port map (
            aclk          => aclk,
            aresetn       => aresetn,

            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tkeep  => s_axis_tkeep,
            s_axis_tlast  => s_axis_tlast,

            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tkeep  => m_axis_tkeep,
            m_axis_tlast  => m_axis_tlast
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
        constant D : std_ulogic_vector(31 downto 0) := x"00101010";
    begin
        wait until falling_edge(aclk);
        aresetn <= '1';
    
        ----------------------------------------------------------------
        -- A: primo beat
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tvalid <= '1';
        s_axis_tdata  <= A;


        ----------------------------------------------------------------
        -- B: beat successivo, nessuno stall
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tdata <= B;

        ----------------------------------------------------------------
        -- C arriva, ma il consumer blocca READY.
        -- B deve rimanere congelato.
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tdata  <= C;
        m_axis_tready <= '0';

        
        wait until falling_edge(aclk);
        s_axis_tdata <= D;        
        
        wait until falling_edge(aclk);
        m_axis_tready <= '1';
        
        wait until falling_edge(aclk);
        s_axis_tdata <= C;
        
        wait until falling_edge(aclk);
        s_axis_tdata <= D;
        ----------------------------------------------------------------
        -- 
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        m_axis_tready <= '1';
        s_axis_tvalid <= '0';
        wait until falling_edge(aclk);
        wait until falling_edge(aclk);
        wait until falling_edge(aclk);
        wait until falling_edge(aclk);
        s_axis_tvalid <= '1';
        wait until falling_edge(aclk);
        
        s_axis_tdata <= C;
        wait until falling_edge(aclk);
        ----------------------------------------------------------------
        -- Nessun nuovo dato
        ----------------------------------------------------------------

        wait until falling_edge(aclk);

        s_axis_tvalid <= '0';
        
        wait until falling_edge(aclk);
        wait until falling_edge(aclk);

        sim_done <= true;
        wait;

    end process;

end architecture;
