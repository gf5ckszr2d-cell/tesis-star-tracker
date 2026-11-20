const fs = require('node:fs');

function readPackets(data) {
  const packets = [];
  const sizes = {
    STY1: p => 13 + p.readUInt32LE(8),
    STC1: p => 9 + 16 * p[4],
    STM1: () => 26,
    STQ2: () => 27,
  };
  let cursor = 0;
  while (cursor < data.length) {
    const tail = data.subarray(cursor);
    const tag = tail.toString('ascii', 0, 4);
    if (!Object.hasOwn(sizes, tag) || (tag === 'STY1' && tail.length < 13) ||
        (tag === 'STC1' && tail.length < 9)) {
      throw new Error(`Cabecera UART inválida en el byte ${cursor}`);
    }
    const size = sizes[tag](tail);
    if (size > tail.length) throw new Error(`Trama ${tag} incompleta en el byte ${cursor}`);
    const packet = tail.subarray(0, size);
    const checksum = packet.subarray(tag === 'STY1' ? 12 : 0, -1)
      .reduce((total, byte) => (total + byte) & 255, 0);
    if (checksum !== packet.at(-1)) throw new Error(`Checksum ${tag} incorrecto en el byte ${cursor}`);
    packets.push({ tag, packet });
    cursor += size;
  }
  return packets;
}

function readPhotos(data) {
  const photos = [];
  let photo;
  for (const { tag, packet } of readPackets(data)) {
    if (tag === 'STY1') {
      photo = { ancho: packet.readUInt16LE(4), alto: packet.readUInt16LE(6) };
      photos.push(photo);
      continue;
    }
    if (!photo) {
      photo = {};
      photos.push(photo);
    }
    if (tag === 'STC1') {
      photo.desborde = Boolean(packet[5]);
      photo.centroides = Array.from({ length: packet[4] }, (_, index) => {
        const start = 8 + 16 * index;
        return { indice: index,
          x: packet.readUInt32LE(start) / 256,
          y: packet.readUInt32LE(start + 4) / 256,
          area: packet.readUInt32LE(start + 8),
          intensidad: packet.readUInt32LE(start + 12) };
      });
    }
    if (tag === 'STM1') {
      if (packet[4] > 8) throw new Error('Cantidad STM1 fuera de rango');
      photo.foto = packet.readUInt32LE(5);
      photo.coincidencias = Array.from({ length: packet[4] }, (_, index) => {
        const observado = packet[9 + 2 * index];
        const id = packet[10 + 2 * index];
        const centroide = photo.centroides?.[observado];
        return { indice: observado, id, ...(centroide && { x: centroide.x, y: centroide.y }) };
      });
    }
    if (tag === 'STQ2') {
      const number = packet.readUInt32LE(6);
      if (photo.foto !== undefined && number !== photo.foto) throw new Error('Número de foto inconsistente');
      photo.foto = number;
      photo.actitud = {
        valida: Boolean(packet[4]),
        coincidencias: packet[5],
        cuaternion: packet[4] ? Array.from({ length: 4 }, (_, index) => packet.readInt32LE(10 + 4 * index) / 32768) : null,
      };
    }
  }
  return photos;
}

if (require.main === module) {
  if (!process.argv[2]) throw new Error('Uso: node leer_uart.cjs captura.bin');
  console.log(JSON.stringify(readPhotos(fs.readFileSync(process.argv[2])), null, 2));
}
module.exports = { readPhotos };
