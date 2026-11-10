import unittest
from pathlib import Path
from PIL import Image
from recibir_imagen import Decoder, HEADER, PIXELS, WIDTH, HEIGHT, save_image

PAYLOAD = (b'STY1\r\nIMG 19213\nFIN\x00\xff' * 5000)[:PIXELS].ljust(PIXELS, b'\x80')
PACKET = HEADER + PAYLOAD + bytes([sum(PAYLOAD) & 255])


class ReceiverTest(unittest.TestCase):
    def test_final_arm_line_without_following_packet(self):
        d = Decoder()
        self.assertEqual(d.feed(b'ARM captura: LINEA_CORTA lineas=120 bytes_min=318\r\n'), [])
        self.assertEqual(d.messages, ['ARM captura: LINEA_CORTA lineas=120 bytes_min=318'])
    def test_arm_diagnostics_outside_binary(self):
        d = Decoder()
        self.assertEqual(d.feed(b'ERROR UART1 overflow\r\n' + PACKET + b'\r\nOK imagen\r\nxxxx'), [PAYLOAD])
        self.assertIn('ERROR UART1 overflow', d.messages)
        self.assertIn('OK imagen', d.messages)
    def test_two_frames_arbitrary_chunks_and_embedded_delimiters(self):
        stream = b'ARM iniciado\r\nS' + PACKET + b'\r\nOK STY1 19200\r\n' + PACKET
        d = Decoder()
        result = []
        for i in range(0, len(stream), 37):
            result.extend(d.feed(stream[i:i+37]))
        self.assertEqual(result, [PAYLOAD, PAYLOAD])

    def test_checksum_and_dimension_rejection_then_recovery(self):
        d = Decoder()
        corrupt = PACKET[:-1] + bytes([PACKET[-1] ^ 255])
        wrong_size = HEADER[:4] + b'\x00'*8
        self.assertEqual(d.feed(wrong_size + corrupt + PACKET), [PAYLOAD])
        self.assertTrue(any('Checksum' in e for e in d.errors))
        self.assertTrue(any('Cabecera' in e for e in d.errors))

    def test_incomplete_timeout_and_next_frame(self):
        d = Decoder()
        self.assertEqual(d.feed(PACKET[:100]), [])
        d.expire()
        self.assertTrue(any('Timeout' in e for e in d.errors))
        self.assertEqual(d.feed(PACKET), [PAYLOAD])

    def test_png_roundtrip(self):
        path = save_image(PAYLOAD, Path(__file__).resolve().parents[1]/'build'/'pc_selftest', False)
        with Image.open(path) as image:
            self.assertEqual(image.size, (WIDTH, HEIGHT))
            self.assertEqual(image.mode, 'L')
            self.assertEqual(image.tobytes(), PAYLOAD)


if __name__ == '__main__':
    unittest.main()
