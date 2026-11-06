library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity converter is
    port(aclk          : in     std_ulogic;
         aresetn       : in     std_ulogic;
         
         --AXI input interface
         s_axis_tvalid : in     std_ulogic;
         s_axis_tready : out    std_ulogic;
         s_axis_tdata  : in     std_ulogic_vector(23 downto 0);
         
         --AXI output interface
         m_axis_tvalid : out    std_ulogic;
         m_axis_tready : in     std_ulogic;
         m_axis_tdata  : out    std_ulogic_vector(7 downto 0));
end entity converter;


--FIFO ARCHITECTURE IMPLEMENTATION

architecture fifo_behav of converter is
    constant exp          : natural := 2;
    constant fifo_depth   : natural := 2**exp;
    constant empty_margin : natural := 1;
    type     fifo_type      is array(0 to fifo_depth-1) of std_ulogic_vector(7 downto 0);
    subtype  index_type     is unsigned(0 to exp - 1);
    
    signal count_p1 : index_type := to_unsigned(0, exp);
    
    function gray(signal data : std_ulogic_vector(23 downto 0)) return std_ulogic_vector is
        variable r, g, b : unsigned(7 downto 0) := (others => '0');
        variable gray    : unsigned(9 downto 0) := (others => '0');
        variable sum     : unsigned(9 downto 0) := (others => '0');
    begin
            b   := unsigned(data  (7 downto 0));
            g   := unsigned(data (15 downto 8));
            r   := unsigned(data(23 downto 16));
            sum :=   resize(r, 10)
                   + resize(g, 10)
                   + resize(b, 10);
            gray := sum/3;
            return std_ulogic_vector(gray(7 downto 0));
    end function;
begin
    PROC_FIFO : process(aclk)
        variable fifo  : fifo_type;
        variable head  : index_type;
        variable tail  : index_type;
        variable count : index_type := to_unsigned(0, exp);
        variable first_iter: boolean:= true;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                head     := to_unsigned(0, exp);
                tail     := to_unsigned(0, exp);
                count    := to_unsigned(0, exp);
                s_axis_tready <= '1';
                m_axis_tvalid <= '0';
                fifo(0) := (others => '0');
                count_p1 <= to_unsigned(0, exp);
            else
                --fifo push on write
                fifo(to_integer(head)) := gray(s_axis_tdata) when s_axis_tready = '1' and s_axis_tvalid = '1';
            
                --update head index on write into fifo
                head := head + (s_axis_tready and s_axis_tvalid);
                
                --update tail index on read from fifo
                tail := tail + (m_axis_tready and m_axis_tvalid);
                
                --fifo pop on read
                m_axis_tdata <= fifo(to_integer(tail))(7 downto 0);
                
                count := head - tail;
                count_p1 <= count;
                
                --update s_axis_tready
                s_axis_tready <= '1' when count < fifo_depth - empty_margin else '0';
                
                --update m_axis_tvalid
                m_axis_tvalid <= '0' when count = 0 or count_p1 = 0 else '1';
            end if;
        end if;
    end process; 
end fifo_behav;