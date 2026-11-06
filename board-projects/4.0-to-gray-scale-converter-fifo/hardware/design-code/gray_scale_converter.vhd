library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity converter is
    port(aclk          : in     std_ulogic;
         aresetn       : in     std_ulogic;
         
         --AXI input interface
         s_axis_tvalid : in     std_ulogic;
         s_axis_tready : out    std_ulogic;
         s_axis_tdata  : in     std_ulogic_vector(31 downto 0);
         s_axis_tkeep  : in     std_ulogic_vector( 3 downto 0);
         s_axis_tlast  : in     std_ulogic;
         
         --AXI output interface
         m_axis_tvalid : out    std_ulogic;
         m_axis_tready : in     std_ulogic;
         m_axis_tdata  : out    std_ulogic_vector(7 downto 0);
         m_axis_tkeep  : out    std_ulogic_vector(0 downto 0);
         m_axis_tlast  : out    std_ulogic);
end entity converter;


--FIFO ARCHITECTURE IMPLEMENTATION

architecture fifo_behav of converter is
    constant fifo_depth : natural := 5;
    constant empty_margin : natural := 1;
    type     fifo_type is array(0 to fifo_depth-1) of std_ulogic_vector(9 downto 0);
    subtype index_type is natural range 0 to fifo_depth-1;
    
    signal fifo     : fifo_type;
    signal head     : index_type;
    signal tail     : index_type;
    signal count    : index_type;
    signal count_p1 : index_type;
    
    signal read_while_write_p1 : std_ulogic;
    
    function gray(signal data : std_ulogic_vector(31 downto 0)) return std_ulogic_vector is
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
    
    function next_index(
        signal index : index_type;
        signal ready : std_ulogic;
        signal valid : std_ulogic) return index_type is
    begin
        if ready = '1' and valid = '1' then
            if index = index_type'high then
                return index_type'low;
            else
                return index + 1;
            end if;
        end if;
        return index;
    end function;
    
    procedure proc_index(
        signal clk     : in    std_ulogic;
        signal resetn  : in    std_ulogic;
        signal index   : inout index_type;
        signal ready   : in    std_ulogic;
        signal valid   : in    std_ulogic) is
    begin
        if rising_edge(clk) then 
            if resetn = '0' then
                index <= index_type'low;
            else
                index <= next_index(index, ready, valid);
             end if;
        end if;        
    end procedure;

begin
    --update index head on write
    PROC_HEAD : proc_index(aclk, aresetn, head, s_axis_tready, s_axis_tvalid);
    --update index tail on read
    PROC_TAIL : proc_index(aclk, aresetn, tail, m_axis_tready, m_axis_tvalid);
    
    PROC_FIFO : process(aclk)
    begin
        if rising_edge(aclk) then
            fifo(head)   <= '1' & s_axis_tlast & gray(s_axis_tdata);
            m_axis_tdata <= fifo(next_index(tail, m_axis_tready, m_axis_tvalid))(7 downto 0);
            m_axis_tlast <= fifo(next_index(tail, m_axis_tready, m_axis_tvalid))(8);
            m_axis_tkeep <= fifo(next_index(tail, m_axis_tready, m_axis_tvalid))(9 downto 9);
        end if;
    end process;
    
    PROC_COUNT : process(head, tail) is
    begin
        if head < tail then
            count <= head - tail + fifo_depth;
        else
            count <= head - tail;
        end if;
    end process;
    
    PROC_COUNT_P1 : process(aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                count_p1 <= 0;
            else
                count_p1 <= count;
            end if;
        end if;
    end process;
    
    PROC_S_AXIS_TREADY : process(count) is
    begin
        if count < fifo_depth - empty_margin then 
            s_axis_tready <= '1';
        else 
            s_axis_tready<= '0';
        end if;
    end process;
    
    PROC_READ_WHILE_WRITE_P1 : process(aclk) is 
    begin
        if rising_edge(aclk) then 
            if aresetn = '0' then
                read_while_write_p1 <= '0';
            else
                read_while_write_p1 <= '0';
                if s_axis_tready = '1' and s_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tvalid = '1' then
                    read_while_write_p1 <= '1';                    
                end if;
            end if;
        end if;
    end process;
    
    PROC_M_AXIS_TVALID : process(count, count_p1, read_while_write_p1) is
    begin
        m_axis_tvalid <= '1';
        
        --if fifo is empty or was empty in the previews cicle
        if count = 0 or count_p1 = 0 then
            m_axis_tvalid <= '0';
        end if;
        
        --if simultaneous read and write while fifo is almost empty
        if count = 1 and read_while_write_p1 = '1' then
            m_axis_tvalid <= '0';
        end if; 
    end process;
    
end fifo_behav;
