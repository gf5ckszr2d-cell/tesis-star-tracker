# Releases de bitstreams Nexys A7

Este directorio conserva bitstreams liberados para la Nexys A7-100T. Cada
release es una copia inmutable y trazable; el bitstream de trabajo
`Top/bitstreams/star_tracker_top_nexys.bit` puede actualizarse con nuevos
builds, pero una carpeta ya publicada dentro de `releases/` no se sobrescribe.

## Convención

- Usar una carpeta nueva por versión: `vMAJOR.MINOR_descripcion_breve/`.
- Guardar `star_tracker_top_nexys.bit` e `INFO.md` dentro de cada carpeta.
- No modificar ni reemplazar una release existente. Si cambia el bitstream, la
  documentación o el resultado de validación, crear una versión nueva.
- Una release `HARDWARE_VERIFIED` es definitiva: no se reemplaza ni se modifica.
- Antes de publicar, comprobar el SHA-256 y que el archivo corresponde al blob
  del commit indicado mediante `git hash-object` y `git rev-parse
  <commit>:<ruta>`.

## Estados admitidos para nuevas releases

- `EXPERIMENTAL`: build preliminar sin cobertura de simulación suficiente.
- `SIMULATED`: simulaciones previstas superadas; hardware aún no validado.
- `HARDWARE_VALIDATION_PENDING`: listo para la prueba física pendiente.
- `HARDWARE_VERIFIED`: prueba física superada y evidencia registrada.
- `FAILED_HARDWARE_VALIDATION`: la prueba física falló; conservar para
  trazabilidad y documentar el resultado.

`HARDWARE_VERIFIED_HISTORICAL` se usa únicamente en la release v0.1 para dejar
claro que existe evidencia histórica de funcionamiento físico, pero la
validación no fue repetida durante este versionado.

## Metadatos mínimos de cada `INFO.md`

- nombre de versión y fecha;
- commit de origen y SHA-256;
- placa y versión de Vivado;
- pinout o cableado relevante;
- estado de validación;
- pruebas realizadas y observaciones.
