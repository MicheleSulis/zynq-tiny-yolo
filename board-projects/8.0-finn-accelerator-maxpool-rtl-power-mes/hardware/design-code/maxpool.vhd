library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- We assume:
-- Square frame of a generic even side
-- Fixed 2x2 kernel
-- Fixed 2 stride

--Backpressure:
--Circuit is designed to acquire about one row of input with output blocked

entity maxpool is
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
end maxpool;

architecture Behavioral of maxpool is
    constant exp          : natural := natural(ceil(log2(real(row_size / 2))));
    constant fifo_depth   : natural := 2**exp; --256
    constant empty_margin : natural := 4;
    type     fifo_type      is array(0 to fifo_depth - 1) of std_ulogic_vector(channel_size * channel_num - 1 downto 0);
    subtype  index_type     is unsigned(exp - 1 downto 0);

    signal ram  : fifo_type;
    -- attribute ram_style : string;
    -- attribute ram_style of ram : signal is "block";
    signal ram_addr : natural range 0 to fifo_depth - 1 := 0;
    
    signal head : unsigned(exp downto 0) := to_unsigned(0, exp + 1);
    --tail punta il prossimo dato non ancora accettato dal consumer
    signal tail : unsigned(exp downto 0) := to_unsigned(row_size / 2, exp + 1);
    
    signal write_enable : boolean;
    signal write_data : std_ulogic_vector(channel_size * channel_num - 1 downto 0);
    signal read_enable  : boolean;
    signal read_data : std_ulogic_vector(channel_size * channel_num - 1 downto 0);
    signal second_row_kernel : boolean := false;
    
    --la logica di uscita dei dati è:
    --se pop_enable = true in quel fronte di clock deve avvenire una lettura in ram
    --pop_valid indica che un dato letto dalla ram e presente in pop_data non è stato ancora trasferito su m_axis_tdata
    signal pop_enable : boolean;
    signal pop_valid : boolean := false;
    signal pop_data : std_ulogic_vector(channel_size * channel_num - 1 downto 0);
begin
    PROC_RAM : process(aclk)
        variable pop_addr : natural range 0 to fifo_depth - 1;
    begin
        if rising_edge(aclk) then
            if aresetn = '1' then
                if write_enable then
                    ram(ram_addr) <= write_data;
                elsif read_enable then
                    read_data <= ram(ram_addr);
                end if;

                if pop_enable then
                    pop_addr := to_integer(tail);
                    
                    --se mvalid = '1' ram(tail) è già presente in uscita, si prepara allora il successivo.
                    if m_axis_tvalid = '1' then
                        pop_addr := pop_addr + 1;
                    end if;

                    pop_data <= ram(pop_addr);
                end if;
                
            end if;
        end if;
    end process;

    --only handles indexes logic and axis acknowledgement
    PROC_FIFO : process(aclk)
        variable next_result : natural range 0 to row_size / 2 + 2;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                head        <= to_unsigned(0, head'length);
                tail        <= to_unsigned(row_size / 2, tail'length);
                second_row_kernel <= false;
                read_enable  <= false;
                write_enable <= false;
                ram_addr     <= 0;
                pop_enable   <= false;
                pop_valid    <= false;
                
                s_axis_tready <= '1';
                m_axis_tvalid <= '0';
            else
                read_enable  <= false;
                write_enable <= false;
                pop_enable   <= false;

                if m_axis_tready = '1' and m_axis_tvalid = '1' then
                    tail <= tail + 1;
                end if;

                if s_axis_tready = '1' and s_axis_tvalid = '1' then
                    if head = row_size  - 1 then
                        head <= to_unsigned(0, head'length);
                        second_row_kernel <= not second_row_kernel;
                        
                        -- Durante la prima riga, tail continua a indicare i risultati precedenti
                        -- ancora da trasmettere. Quando sono tutti usciti, rimane a row_size/2:
                        -- questo indica che non ci sono altri risultati pronti da leggere.
                        --
                        -- Non lo azzero prima: tail = 0 farebbe interpretare i parziali della
                        -- nuova prima riga come risultati definitivi ancora da trasmettere.
                        --
                        -- Alla fine della prima riga posso azzerarlo: sto entrando nella seconda,
                        -- che completera' i nuovi risultati a partire dalla cella 0.
                        -- pop_enable aspettera' che ciascun risultato sia effettivamente pronto.
                        -- La gestione di sready garantisce che i vecchi risultati siano gia' usciti.
                        if not second_row_kernel then
                            tail <= to_unsigned(0, tail'length);
                        end if;
                    else
                        head <= head + 1;
                    end if;
                    
                    if head(0 downto 0) = 1 then
                        -- acknowledgment del secondo pixel della coppia completato, programmo la scrittura in ram
                        write_enable <= true;
                        ram_addr <= to_integer(shift_right(head, 1));
                    elsif not second_row_kernel then
                        -- preparo il primo parziale per la seconda riga
                        if head = row_size - 2 then
                            read_enable <= true;
                            ram_addr <= 0;
                        end if;
                    elsif head < row_size - 2 then
                        -- preparo il parziale della coppia successiva
                        read_enable <= true;
                        ram_addr <= to_integer(shift_right(head, 1)) + 1;
                    end if;
                end if;

                next_result := to_integer(tail);

                if m_axis_tvalid = '1' then
                    next_result := next_result + 1;
                end if;

                if pop_valid then
                    next_result := next_result + 1;
                end if;
                
                --se non c'è un dato valido in uscita o se c'è ma viene accettato su questo fronte,
                --devo preparare un nuovo dato per il successivo clock
                if m_axis_tvalid = '0' or m_axis_tready = '1' then
                    if pop_valid then
                        m_axis_tdata  <= pop_data;
                        m_axis_tvalid <= '1';
                        pop_valid    <= false;
                    
                    --se il prossimo risultato da trasmettere è quello che 
                    --sto scrivendo ora in ram, mando in uscita direttamente
                    --il dato, senza dover aspettare di scriverlo e poi rileggerlo
                    --La condizione è: 
                    --non ci sia già una lettura in corso,
                    --ci sia una scrittura in ram,
                    --l'indirizzo corrisponda al risultato atteso,
                    --il dato sia un massimo definitivo, non un parziale della prima riga
                    elsif not pop_enable and write_enable
                        and ram_addr = next_result
                        and ((second_row_kernel and head /= 0)
                             or (not second_row_kernel and head = 0)) then

                        m_axis_tdata  <= write_data;
                        m_axis_tvalid <= '1';
                        next_result := next_result + 1;

                    else
                        m_axis_tvalid <= '0';
                    end if;
                end if;

                -- la RAM esegue la richiesta del clock precedente
                if pop_enable then
                    pop_valid <= true;
                end if;

                -- richiedo il prossimo risultato non ancora anticipato
                if not pop_enable
                    and (not pop_valid
                         or m_axis_tvalid = '0' or m_axis_tready = '1') then
                    --programmo il pop solo se next_result è indietro rispetto al numero di massimi calcolati 
                    --(altrimenti mando direttamente il dato in uscita senza aspettare di leggerlo dalla ram)
                    if second_row_kernel then
                        pop_enable <=
                            next_result < to_integer(shift_right(head, 1));
                    else
                        --se sono nella prima riga vuol dire che ho finito di elaborare le due righe precedenti.
                        --programmo letture solo se ci sono stati degli stalli e devo ancora trasmettere massimi
                        --validi (next result <208)
                        pop_enable <= next_result < row_size / 2;
                    end if;
                end if;

                s_axis_tready <= '1';
                
                --logica per determinare se sono pronto ad accettare il prossimo dato in ingresso
                if head = row_size - 1
                    and s_axis_tready = '1' and s_axis_tvalid = '1' then

                    if second_row_kernel and tail = 0
                        and not (m_axis_tready = '1' and m_axis_tvalid = '1') then
                        s_axis_tready <= '0';
                    end if;

                elsif not second_row_kernel then
                    if head(0 downto 0) = 1
                        and s_axis_tready = '1' and s_axis_tvalid = '1' then

                        s_axis_tready <= '1' when
                            shift_right(head, 1) + 1
                            < tail + (m_axis_tready and m_axis_tvalid)
                            else '0';
                    else
                        s_axis_tready <= '1' when
                            shift_right(head, 1)
                            < tail + (m_axis_tready and m_axis_tvalid)
                            else '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    comparator : for channel in 0 to channel_num - 1 generate 
        process(aclk)
            variable max : std_ulogic_vector(channel_size - 1 downto 0);
        begin
            if rising_edge(aclk) then
                if aresetn = '0' then
                else
                    if (s_axis_tready = '1' and s_axis_tvalid = '1') then
                        if head(0 downto 0) = 0 and second_row_kernel = false then
                            max := s_axis_tdata((channel + 1) * channel_size - 1 downto channel * channel_size);
                        end if;
                        
                        if head(0 downto 0) = 1 and second_row_kernel = false then
                            max := s_axis_tdata((channel + 1) * channel_size - 1 downto channel * channel_size)
                                 when s_axis_tdata((channel + 1) * channel_size - 1 downto channel * channel_size) 
                                 > max;
                            write_data((channel + 1) * channel_size - 1 downto channel * channel_size) <= max;
                        end if;
                        
                        if head(0 downto 0) = 0 and second_row_kernel = true then
                            max := s_axis_tdata((channel + 1) * channel_size - 1 downto channel * channel_size) 
                                when s_axis_tdata((channel + 1) * channel_size - 1 downto channel * channel_size)
                                > read_data((channel + 1) * channel_size - 1 downto channel * channel_size)
                                 else read_data((channel + 1) * channel_size - 1 downto channel * channel_size);
                        end if;
                        
                        if head(0 downto 0) = 1 and second_row_kernel = true then
                            max := s_axis_tdata((channel + 1) * channel_size - 1 downto channel * channel_size)
                                when s_axis_tdata((channel + 1) * channel_size - 1 downto channel * channel_size) > max;
                            write_data((channel + 1) * channel_size - 1 downto channel * channel_size) <= max;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;
end Behavioral;
