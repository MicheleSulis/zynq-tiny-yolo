library ieee;
use ieee.std_logic_1164.all;

entity maxpool_wrapper is
    generic (row_size : natural; 
             channel_size : natural;
             channel_num : natural);
    
    port (aclk : in std_ulogic;
          aresetn : in std_ulogic;
          
          s_axis_tdata : in std_ulogic_vector(channel_size * channel_num - 1 downto 0);
          s_axis_tready : out std_ulogic;
          s_axis_tvalid : in std_ulogic;
          
          m_axis_tdata : out std_ulogic_vector(channel_size * channel_num - 1 downto 0);
          m_axis_tready : in std_ulogic;
          m_axis_tvalid : out std_ulogic);
end maxpool_wrapper;

architecture structural of maxpool_wrapper is
    
begin
    maxpool : entity work.maxpool(Behavioral)
    generic map(row_size => row_size,
                channel_size => channel_size,
                channel_num => channel_num)
    port map(aclk => aclk,
             aresetn => aresetn,
             
             s_axis_tdata => s_axis_tdata,
             s_axis_tready => s_axis_tready,
             s_axis_tvalid => s_axis_tvalid,
             
             m_axis_tdata => m_axis_tdata,
             m_axis_tready => m_axis_tready,
             m_axis_tvalid => m_axis_tvalid);

end structural;
