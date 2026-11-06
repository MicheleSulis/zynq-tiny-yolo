library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    port(aclk          : in     std_ulogic;
         aresetn       : in     std_ulogic;

         --AXI input interface
         s_axis_tvalid : in     std_ulogic;
         s_axis_tready : out    std_ulogic;
         s_axis_tdata  : in     std_ulogic_vector(7 downto 0);

         --AXI output interface
         m_axis_tvalid : out    std_ulogic;
         m_axis_tready : in     std_ulogic;
         m_axis_tdata  : out    std_ulogic_vector(7 downto 0);
         m_axis_tlast  : out    std_ulogic);
end entity counter;


--FIFO ARCHITECTURE IMPLEMENTATION

architecture fifo_behav of counter is
    constant exp          : natural := 2;
    constant fifo_depth   : natural := 2**exp;
    constant empty_margin : natural := 1;
    type     fifo_type      is array(0 to fifo_depth-1) of std_ulogic_vector(7 downto 0);
    subtype  index_type     is unsigned(0 to exp - 1);
    
    signal count_p1 : index_type := to_unsigned(0, exp);
begin
    PROC_FIFO : process(aclk)
        variable fifo  : fifo_type;
        variable head  : index_type;
        variable tail  : index_type;
        variable count : index_type := to_unsigned(0, exp);
        variable total_count : unsigned(0 to 31);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                head     := to_unsigned(0, exp);
                tail     := to_unsigned(0, exp);
                count    := to_unsigned(0, exp);
                total_count := to_unsigned(0, 32);
                s_axis_tready <= '1';
                m_axis_tvalid <= '0';
                m_axis_tlast  <= '0';
                fifo(0) := (others => '0');
                count_p1 <= to_unsigned(0, exp);
            else
                --fifo push on write
                fifo(to_integer(head)) := s_axis_tdata when s_axis_tready = '1' and s_axis_tvalid = '1';
            
                --update head index on write into fifo
                head := head + (s_axis_tready and s_axis_tvalid);
                
                --update tail index on read from fifo
                if (m_axis_tready = '1' and m_axis_tvalid = '1') then
                    tail := tail + 1;
                    total_count := total_count + 1;
                end if;
                
                --fifo pop on read
                m_axis_tdata <= fifo(to_integer(tail))(7 downto 0);
                
                count := head - tail;
                count_p1 <= count;
                
                --update s_axis_tready
                s_axis_tready <= '1' when count < fifo_depth - empty_margin else '0';
                
                --update m_axis_tvalid
                m_axis_tvalid <= '0' when count = 0 or count_p1 = 0 else '1';
                
                --update m_axis_tlast
                m_axis_tlast <= '1' when total_count = (13*13*18) - 1 else '0';
                
                total_count := to_unsigned(0, 32) when total_count = 13*13*18 else total_count;
            end if;
        end if;
    end process; 
end fifo_behav;