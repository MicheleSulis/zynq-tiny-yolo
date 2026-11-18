library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity repacker_wrapper is
    port(aclk          : in     std_ulogic;
         aresetn       : in     std_ulogic;

         --AXI input interface
         s_axis_tvalid : in     std_ulogic;
         s_axis_tready : out    std_ulogic;
         s_axis_tdata  : in     std_ulogic_vector(31 downto 0);

         --AXI output interface
         m_axis_tvalid : out    std_ulogic;
         m_axis_tready : in     std_ulogic;
         m_axis_tdata  : out    std_ulogic_vector(23 downto 0));
end repacker_wrapper;

architecture struct of repacker_wrapper is
begin
    repacker : entity work.repacker(fifo_behav)
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
end struct;
