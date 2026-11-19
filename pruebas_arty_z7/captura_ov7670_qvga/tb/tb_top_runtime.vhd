entity tb_top_runtime is end;
architecture sim of tb_top_runtime is
begin
    test: entity work.tb_captura_uart
        generic map(TEST_RUNTIME=>true);
end;
