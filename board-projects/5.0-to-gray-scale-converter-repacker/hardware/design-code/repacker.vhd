library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity repacker is
    port(aclk          : in     std_ulogic;
         aresetn       : in     std_ulogic;
         
         --AXI input interface
         s_axis_tvalid : in     std_ulogic;
         s_axis_tready : out    std_ulogic;
         s_axis_tdata  : in     std_ulogic_vector(31 downto 0);
         
         --AXI output interface
         m_axis_tvalid : out    std_ulogic;
         m_axis_tready : in     std_ulogic;
         m_axis_tdata  : out    std_ulogic_vector(23 downto 0)
         );
end entity repacker;


--FIFO ARCHITECTURE IMPLEMENTATION

architecture fifo_behav of repacker is
    constant exp          : natural := 5;
    constant fifo_depth   : natural := 2**exp; --fifo depth 32
    constant empty_margin : natural := 4;
    type     fifo_type      is array(0 to fifo_depth-1) of std_ulogic_vector(23 downto 0);
    subtype  index_type     is unsigned(0 to exp - 1);
    
    signal count_p1 : index_type := to_unsigned(0, exp);
    
    
begin
    PROC_FIFO : process(aclk)
        variable fifo  : fifo_type;
        variable head  : index_type;
        variable tail  : index_type;
        variable count : index_type := to_unsigned(0, exp);
        variable first_iter: boolean:= true;
        variable secnd_iter: boolean:= false; --if both false we are on the third iter, obviously can't be both true
        variable res   : std_ulogic_vector(15 downto 0);
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
                first_iter := true;
                secnd_iter := false;
            else
                 --update tail index on read from fifo
                if (m_axis_tready = '1' and m_axis_tvalid = '1') then
                    tail := tail + 1;
                    count := count - 1;
                end if;
                
                --fifo pop on read
                m_axis_tdata <= fifo(to_integer(tail))(23 downto 0);
                
                --fifo push on write (repacked xxxx -> xxx saving 25% of bandwith)
                if(s_axis_tready = '1' and s_axis_tvalid = '1') then
                    if first_iter = true then
                        fifo(to_integer(head)) := s_axis_tdata(23 downto 0);
                        res(15 downto 8) := s_axis_tdata(31 downto 24);
                        first_iter := false;
                        secnd_iter := true;
                        count:=count+1;
                    else 
                        if secnd_iter = true then
                            fifo(to_integer(head)) :=  s_axis_tdata(15 downto 0) & res(15 downto 8);
                            res(15 downto 0) := s_axis_tdata(31 downto 16);
                            secnd_iter := false;
                            count:=count+1;
                        else
                            fifo(to_integer(head)) := s_axis_tdata(7 downto 0) & res(15 downto 0);
                            head := head + 1;
                            fifo(to_integer(head)) := s_axis_tdata(31 downto 8);
                            first_iter := true;
                            count:=count+2;
                        end if;
                    end if;    
                end if;         
            
                --update head index on write into fifo
                head := head + (s_axis_tready and s_axis_tvalid);
                
                count_p1 <= count;
                
                --update s_axis_tready
                s_axis_tready <= '1' when count < fifo_depth - empty_margin else '0';
                
                --update m_axis_tvalid
                m_axis_tvalid <= '0' when count = 0 or count_p1 = 0 
                or (count_p1 = 1 and m_axis_tready = '1' and m_axis_tvalid = '1')
                else '1';
            end if;
        end if;
    end process;
end fifo_behav;