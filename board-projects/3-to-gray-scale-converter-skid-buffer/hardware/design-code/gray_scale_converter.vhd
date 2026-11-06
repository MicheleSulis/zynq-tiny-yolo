library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity converter is
    port(aclk          : in     std_ulogic; 
         aresetn       : in     std_ulogic;
         s_axis_tvalid : in     std_ulogic;
         s_axis_tready : out    std_ulogic;
         s_axis_tlast  : in     std_ulogic; 
         s_axis_tdata  : in     std_ulogic_vector(31 downto 0); 
         s_axis_tkeep  : in     std_ulogic_vector(3 downto 0);
         
         m_axis_tvalid : out    std_ulogic;
         m_axis_tready : in     std_ulogic;
         m_axis_tlast  : out    std_ulogic;
         m_axis_tdata  : out    std_ulogic_vector(7 downto 0);
         m_axis_tkeep  : out    std_ulogic_vector(0 downto 0));
end entity converter;

architecture behavioural of converter is
signal enable     : std_ulogic;
signal int_tvalid : std_ulogic;
begin
    m_axis_tvalid <= int_tvalid;
    enable <= m_axis_tready or not int_tvalid;
    
    --s_axis_tready is not registered
    s_axis_tready <= aresetn and enable;
    
    Stage : process(aclk)
        variable r, g, b    : unsigned(7 downto 0)           := (others => '0');
        variable gray       : unsigned(9 downto 0)           := (others => '0');
        variable sum        : unsigned(9 downto 0)           := (others => '0');
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                int_tvalid <= '0';
            elsif enable = '1' then
                --m_axis_tvalid
                int_tvalid <= s_axis_tvalid;
                
                --m_axis_tdata
                b   := unsigned(s_axis_tdata  (7 downto 0));
                g   := unsigned(s_axis_tdata (15 downto 8));
                r   := unsigned(s_axis_tdata(23 downto 16));
                sum :=   resize(r, 10)
                       + resize(g, 10)
                       + resize(b, 10);
                gray := sum/3;
                m_axis_tdata <= std_ulogic_vector(gray(7 downto 0));
            
                --m_axis_tlast
                m_axis_tlast <= s_axis_tlast;
                
                --m_axis_tkeep
                m_axis_tkeep <= "1";
            end if;
        end if;
    end process;
end behavioural;