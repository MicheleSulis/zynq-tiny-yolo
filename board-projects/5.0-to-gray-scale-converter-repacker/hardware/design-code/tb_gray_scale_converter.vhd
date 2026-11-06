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
    
    signal m_axis_tvalid : std_ulogic;
    signal m_axis_tready : std_ulogic := '1';
    signal m_axis_tdata  : std_ulogic_vector(23 downto 0);

    signal sim_done : boolean := false;

begin

    dut : entity work.repacker(fifo_behav)
        port map (
            aclk          => aclk,
            aresetn       => aresetn,

            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tdata  => s_axis_tdata,

            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tdata  => m_axis_tdata
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
        constant A : std_ulogic_vector(31 downto 0) := x"10203011";
        constant B : std_ulogic_vector(31 downto 0) := x"21311222";
        constant C : std_ulogic_vector(31 downto 0) := x"32132333";
        constant D : std_ulogic_vector(31 downto 0) := x"14243415";
        constant E : std_ulogic_vector(31 downto 0) := x"25351626";
        constant F : std_ulogic_vector(31 downto 0) := x"36172737";
    begin
        wait until falling_edge(aclk);
        aresetn <= '1';
        s_axis_tvalid <= '1';
        s_axis_tdata  <=  A;
        m_axis_tready <= '0';
        
        wait until falling_edge(aclk);
        s_axis_tdata  <= B;
        
        wait until falling_edge(aclk);
        s_axis_tdata  <= C;
        
        wait until falling_edge(aclk);
        s_axis_tdata <= D;
        m_axis_tready <= '1';
        
        wait until falling_edge(aclk);
        s_axis_tdata <= E;
        
        wait until falling_edge(aclk);
        s_axis_tdata <= F;
        
        wait until falling_edge(aclk);
        s_axis_tvalid <= '0';
        
        wait until falling_edge(aclk);
        wait until falling_edge(aclk);
        wait until falling_edge(aclk);
        
        wait until falling_edge(aclk);
        
                
        sim_done <= true;
        wait;

    end process;

end architecture;

