# Mecanismo gimbal de tres grados de libertad

Incorporado el 13 de noviembre de 2026 desde
`C:\Users\alexa\OneDrive\Documentos\Mecanismo para tesis`.
Alexander confirmó que el futuro banco utilizará un gimbal de tres grados de
libertad. La revisión se realiza con ese objetivo; la descripción anterior de
cámara fija en el manuscrito queda pendiente de una actualización posterior.

## Abrir y consultar

- **Auditoría integral vigente:** [centro óptico, movimiento y colisiones](Auditoria_integral_20261113/README.md), terminada el 14/11/2026; incluye ejes nativos y 125 posturas.
- **Revisión vigente de alineación:** [Alineacion_R1_20261113](Alineacion_R1_20261113/README.md), con ensamblaje corregido y ambas imágenes.
- Ensamblaje completo: [CAD_portable/mecanismo compoleto.iam](CAD_portable/mecanismo%20compoleto.iam).
- Planos originales, cinco hojas: [Original/PLANITOS.pdf](Original/PLANITOS.pdf).
- Dictamen y acciones necesarias: [REVISION_BANCO.md](REVISION_BANCO.md).
- Evidencia numérica: [Revision_20261113/verificacion_paquete.json](Revision_20261113/verificacion_paquete.json).

**Dictamen actualizado:** el centro mecánico de R1 permanece fijo en las posturas
probadas; la pupila de entrada real sigue sin localizarse. Se detectaron choques
entre carcasas/base en 20 de 125 combinaciones grandes. Todavía no está validado
como referencia angular para el banco. La revisión inicial y los archivos recibidos
se conservan como evidencia histórica.

## Conservación y portabilidad

`Original/` contiene una copia idéntica de los 16 archivos de la carpeta encontrada,
incluido `OldVersions`. Los archivos originales externos no se movieron ni editaron.

`CAD_portable/` reúne los ocho archivos CAD actuales de esa carpeta y cuatro
dependencias recuperadas de Descargas: cámara, servo y tornillos M3x5/M3x10.
Se verificó que las ocho referencias directas del ensamblaje se resuelven dentro
de esta carpeta. Los doce archivos se conservan sin modificar sus bytes; Inventor
resolvió por nombre local las rutas históricas almacenadas. Mantenerlos juntos.
La apertura de la presentación `.ipn` y las versiones históricas no fue verificada.

`Revision_20261113/` contiene manifiestos SHA-256, planos renderizados y registros
de inspección de Inventor 2027.2. La inspección inicial sin dependencias está en
`inspeccion_original.txt`; no usar su comprobación de interferencias sobre un
ensamblaje incompleto como resultado válido. `inspeccion_CAD.txt` corresponde al
paquete completo. El intento de renderizado CAD fuera de pantalla produjo una
imagen vacía y fue descartado tras inspección visual; el texto `RENDER_OK=true`
de esos registros solo indica que la llamada terminó, no una imagen aprobada.
La evidencia visual utilizada son las cinco hojas del PDF original.

En la revisión inicial no se rediseñó ni guardó el ensamblaje. La liberación
de restricciones se ensayó exclusivamente en memoria y se cerró sin guardar.
No se modificó RTL, configuración de cámara, UART ni hardware físico.
La corrección posterior solicitada queda documentada en la carpeta R1.

## Reproducir la inspección

Con Inventor 2027 instalado y sin otra sesión de Inventor en uso:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Inventor\Mecanismo_3GDL\Revision_20261113\Inspeccionar_mecanismo.ps1 -Ensamblaje '.\Inventor\Mecanismo_3GDL\CAD_portable\mecanismo compoleto.iam'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Inventor\Mecanismo_3GDL\Revision_20261113\Revisar_ejes.ps1
python .\Inventor\Mecanismo_3GDL\Revision_20261113\Verificar_paquete.py
```

Los scripts COM usan una instancia oculta y cierran sin guardar. Requieren acceso
a COM de Inventor. Los manifiestos describen el estado recibido; una futura
modificación deliberada del diseño debe conservarlos y registrar su propia revisión.
