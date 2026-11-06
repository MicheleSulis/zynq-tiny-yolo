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
begin
    m_axis_tdata <= s_axis_tdata(23 downto 0);
    m_axis_tvalid <= s_axis_tvalid and aresetn;
    s_axis_tready <= m_axis_tready and aresetn;
end fifo_behav;
