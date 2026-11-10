library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Read-only diagnostics. Does not control capture or change the image packet.
-- Snapshot stays stable until the next completed frame (or reset).
entity capture_frame_diag is
    generic (FRAME_WIDTH : positive := 160; FRAME_HEIGHT : positive := 120);
    port (
        pclk, rst, enable, vsync, href, pixel_valid : in std_logic;
        frame_done, capture_error, store_error : in std_logic;
        status : out std_logic_vector(63 downto 0)
    );
end;
architecture rtl of capture_frame_diag is
    signal enabled_prev, tracking, sync_seen, in_frame, line_open, pending : std_logic := '0';
    signal sequence_bit : std_logic := '0';
    signal line_bytes, min_bytes, max_bytes : natural range 0 to 4095 := 0;
    signal lines, first_bad_line : natural range 0 to 255 := 0;
    signal pixels : natural range 0 to 131071 := 0;
    signal first_reason : natural range 0 to 15 := 0;
    signal result : std_logic_vector(63 downto 0) := (others=>'0');
begin
    status <= result;
    process(pclk)
        variable reason : natural range 0 to 15;
        procedure close_line is
            variable r : natural;
        begin
            if lines < 255 then lines <= lines+1; end if;
            if line_bytes < min_bytes then min_bytes <= line_bytes; end if;
            if line_bytes > max_bytes then max_bytes <= line_bytes; end if;
            r := 0;
            if line_bytes mod 2 /= 0 then r := 3;
            elsif line_bytes < 2*FRAME_WIDTH then r := 1;
            elsif line_bytes > 2*FRAME_WIDTH then r := 2; end if;
            if first_reason = 0 and r /= 0 then
                first_reason <= r; first_bad_line <= lines;
            end if;
            line_bytes <= 0; line_open <= '0';
        end procedure;
    begin
        if rising_edge(pclk) then
            if rst='1' then
                enabled_prev<='0'; tracking<='0'; sync_seen<='0'; in_frame<='0';
                line_open<='0'; pending<='0'; sequence_bit<='0';
                line_bytes<=0; min_bytes<=4095; max_bytes<=0; lines<=0; pixels<=0;
                first_reason<=0; first_bad_line<=255; result<=(others=>'0');
            else
                enabled_prev <= enable;
                pending <= frame_done;
                if enable='1' and enabled_prev='0' then
                    tracking<='1'; sync_seen<='0'; in_frame<='0'; line_open<='0';
                    line_bytes<=0; min_bytes<=4095; max_bytes<=0; lines<=0; pixels<=0;
                    first_reason<=0; first_bad_line<=255;
                elsif tracking='1' then
                    if pixel_valid='1' and pixels<131071 then pixels<=pixels+1; end if;
                    if vsync='1' then
                        sync_seen<='1'; in_frame<='0';
                        if line_open='1' then close_line; end if;
                    elsif sync_seen='1' then
                        in_frame<='1';
                        if href='1' then
                            line_open<='1';
                            if line_bytes<4095 then line_bytes<=line_bytes+1; end if;
                        elsif line_open='1' then close_line; end if;
                    end if;
                end if;
                -- One cycle after frame_done: store/capture errors have settled.
                if pending='1' then
                    reason := first_reason;
                    if reason=0 then
                        if lines<FRAME_HEIGHT then reason:=4;
                        elsif lines>FRAME_HEIGHT then reason:=5;
                        elsif pixels/=FRAME_WIDTH*FRAME_HEIGHT then reason:=6;
                        elsif store_error='1' then reason:=7;
                        elsif capture_error='1' then reason:=8; end if;
                    end if;
                    result(3 downto 0) <= std_logic_vector(to_unsigned(reason,4));
                    result(11 downto 4) <= std_logic_vector(to_unsigned(lines,8));
                    -- Bit 23 extends pixel count to 17 bits for QVGA.
                    if min_bytes > 2047 then result(22 downto 12) <= (others=>'1');
                    else result(22 downto 12) <= std_logic_vector(to_unsigned(min_bytes,11)); end if;
                    if pixels >= 65536 then result(23)<='1'; else result(23)<='0'; end if;
                    result(35 downto 24) <= std_logic_vector(to_unsigned(max_bytes,12));
                    result(51 downto 36) <= std_logic_vector(to_unsigned(pixels mod 65536,16));
                    result(59 downto 52) <= std_logic_vector(to_unsigned(first_bad_line,8));
                    result(60) <= store_error; result(61) <= capture_error;
                    result(62) <= not sequence_bit; result(63) <= '1';
                    sequence_bit <= not sequence_bit; tracking<='0';
                end if;
            end if;
        end if;
    end process;
end;
