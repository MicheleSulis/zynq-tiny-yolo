library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_maxpool is
end entity;

architecture behavioural of tb_maxpool is
    constant row_size : natural := 8;
    constant row_num : natural := 4;
    constant result_num : natural := row_size * row_num / 4;

    subtype pixel_type is std_ulogic_vector(31 downto 0);
    type matrix_type is array(natural range <>, natural range <>) of pixel_type;

    -- Quattro righe da otto pixel. Ogni cifra esadecimale e' un canale da 4 bit.
    constant input_data : matrix_type(0 to 3, 0 to 7) := (
        (x"FED2C502", x"2C2F7E1F", x"CA18FC42", x"8B2D3218", x"6D5F124F", x"2B510F6D", x"873E36C9", x"70AFF5EA"),
        (x"480AFBA8", x"7958C969", x"23ACAD1E", x"5A4A3C23", x"F18B8C62", x"2C096E71", x"6C3B6BCC", x"15E3B283"),
        (x"9148F0ED", x"F776A381", x"C34466FB", x"64C46EF4", x"C6ED0841", x"BD38A71E", x"06193F19", x"0FBDA969"),
        (x"72427929", x"07ACAB63", x"08E607EE", x"7E942A64", x"5416E139", x"935A1FEC", x"2E231B12", x"741BE3A5")
    );

    -- Due righe da quattro pixel, precalcolate prendendo il massimo di ogni
    -- finestra 2x2, separatamente per ciascuno degli otto canali.
    constant expected_data : matrix_type(0 to 1, 0 to 3) := (
        (x"FEDFFEAF", x"CBADFD4E", x"FD8F8F7F", x"8CEFFBEC"),
        (x"F7ACFBED", x"CEE66EFE", x"CDEDEFEE", x"7FBDEFA9")
    );

    signal aclk : std_ulogic := '0';
    signal aresetn : std_ulogic := '0';
    signal s_axis_tdata : pixel_type := (others => '0');
    signal s_axis_tready : std_ulogic;
    signal s_axis_tvalid : std_ulogic := '0';
    signal m_axis_tdata : pixel_type;
    signal m_axis_tready : std_ulogic := '0';
    signal m_axis_tvalid : std_ulogic;
    signal test_case : natural range 0 to 3 := 0;
    signal reset_pending : boolean := false;
    signal received : natural := 0;
    signal sim_done : boolean := false;
begin
    dut : entity work.maxpool(Behavioral)
        generic map(row_size => row_size,
                    channel_size => 4,
                    channel_num => 8)
        port map(aclk => aclk,
                 aresetn => aresetn,
                 s_axis_tdata => s_axis_tdata,
                 s_axis_tready => s_axis_tready,
                 s_axis_tvalid => s_axis_tvalid,
                 m_axis_tdata => m_axis_tdata,
                 m_axis_tready => m_axis_tready,
                 m_axis_tvalid => m_axis_tvalid);

    clock : process
    begin
        while not sim_done loop
            aclk <= '0';
            wait for 2.5 ns;
            aclk <= '1';
            wait for 2.5 ns;
        end loop;
        wait;
    end process;

    -- Il consumer controlla soltanto TREADY: non deve prevedere quando il
    -- MaxPool produrra' i risultati. I segnali cambiano sul fronte di discesa.
    PROC_READY : process(aclk)
        variable cycle : natural := 0;
    begin
        if falling_edge(aclk) then
            if aresetn = '0' then
                cycle := 0;
                m_axis_tready <= '0';
            else
                if reset_pending then
                    m_axis_tready <= '0';
                elsif test_case = 1 and cycle mod 11 >= 7 then
                    m_axis_tready <= '0';
                elsif test_case = 2 and cycle < 8 * row_size then
                    m_axis_tready <= '0';
                else
                    m_axis_tready <= '1';
                end if;
                cycle := cycle + 1;
            end if;
        end if;
    end process;

    -- Il confronto avanza nella matrice attesa soltanto quando il consumer
    -- accetta un risultato. Lo stesso processo controlla la stabilita' AXI.
    PROC_CHECK : process(aclk)
        variable count : natural := 0;
        variable input_count : natural := 0;
        variable result_row : natural := 0;
        variable result_column : natural := 0;
        variable stalled : boolean := false;
        variable held_data : pixel_type;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                count := 0;
                input_count := 0;
                result_row := 0;
                result_column := 0;
                stalled := false;
                received <= 0;
            else
                if s_axis_tvalid = '1' and s_axis_tready = '1' then
                    input_count := input_count + 1;
                end if;

                if stalled then
                    assert m_axis_tvalid = '1' and m_axis_tdata = held_data
                        report "TDATA o TVALID modificati durante uno stallo" severity failure;
                end if;

                if m_axis_tvalid = '1' and m_axis_tready = '1' then
                    assert count < result_num
                        report "Risultati in eccesso" severity failure;
                    assert input_count >= (2 * result_row + 1) * row_size + 2 * result_column + 2
                        report "Risultato prodotto prima di ricevere il kernel completo" severity failure;
                    assert m_axis_tdata = expected_data(result_row, result_column)
                        report "Test " & integer'image(test_case) &
                               ", risultato " & integer'image(count) &
                               ": atteso 0x" & to_hstring(expected_data(result_row, result_column)) &
                               ", ricevuto 0x" & to_hstring(m_axis_tdata)
                        severity failure;

                    count := count + 1;
                    received <= count;
                    if result_column = row_size / 2 - 1 then
                        result_column := 0;
                        result_row := result_row + 1;
                    else
                        result_column := result_column + 1;
                    end if;
                end if;

                stalled := m_axis_tvalid = '1' and m_axis_tready = '0';
                held_data := m_axis_tdata;
            end if;
        end if;
    end process;

    stimulus : process
        variable backpressure_seen : boolean;

        procedure reset_dut is
        begin
            wait until falling_edge(aclk);
            aresetn <= '0';
            s_axis_tvalid <= '0';
            for cycle in 1 to 5 loop
                wait until rising_edge(aclk);
            end loop;
            wait until falling_edge(aclk);
            aresetn <= '1';
        end procedure;

        -- La stessa procedura invia tutti i pixel in tutti gli scenari.
        procedure send_pixel(data : pixel_type) is
        begin
            wait until falling_edge(aclk);
            s_axis_tdata <= data;
            s_axis_tvalid <= '1';
            loop
                wait until rising_edge(aclk);
                exit when s_axis_tready = '1';
                backpressure_seen := true;
            end loop;
        end procedure;
    begin
        -- 0: continuo; 1: pause e stalli periodici; 2: stallo prolungato;
        -- 3: reset con risultati ancora da trasmettere.
        for test in 0 to 3 loop
            test_case <= test;
            backpressure_seen := false;
            reset_pending <= test = 3;
            reset_dut;

            if test = 3 then
                -- Carico dati diversi da quelli del test e blocco l'uscita.
                for row in 0 to 1 loop
                    for column in 0 to row_size - 1 loop
                        send_pixel(not input_data(row, column));
                    end loop;
                end loop;
                wait until falling_edge(aclk);
                s_axis_tvalid <= '0';
                for cycle in 1 to 5 loop
                    wait until rising_edge(aclk);
                end loop;
                assert m_axis_tvalid = '1'
                    report "Il test di reset richiede un risultato ancora da trasmettere" severity failure;
                reset_dut;
                reset_pending <= false;
            end if;

            for row in 0 to row_num - 1 loop
                for column in 0 to row_size - 1 loop
                    if test = 1 and (row * row_size + column) mod 7 = 3 then
                        wait until falling_edge(aclk);
                        s_axis_tvalid <= '0';
                    end if;
                    send_pixel(input_data(row, column));
                end loop;
            end loop;
            wait until falling_edge(aclk);
            s_axis_tvalid <= '0';

            for cycle in 1 to 20 * row_size + 100 loop
                wait until rising_edge(aclk);
                exit when received = result_num;
            end loop;
            assert received = result_num
                report "Risultati mancanti" severity failure;
            if test = 2 then
                assert backpressure_seen
                    report "Lo stallo lungo non ha verificato la backpressure in ingresso" severity failure;
            end if;
            for cycle in 1 to 20 loop
                wait until rising_edge(aclk);
            end loop;
            report "PASS test " & integer'image(test) & ": 8 risultati corretti" severity note;
        end loop;
        report "PASS: tutti i test maxpool" severity note;
        sim_done <= true;
        std.env.stop;
        wait;
    end process;

    watchdog : process
    begin
        wait for 50 us;
        assert false report "Timeout: il testbench non ha terminato" severity failure;
        wait;
    end process;
end architecture;
