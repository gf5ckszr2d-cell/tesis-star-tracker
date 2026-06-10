# Port Arty Z7-10

Esta carpeta contiene el port preliminar para correr el flujo actual de captura en una
Digilent Arty Z7-10 sin modificar el flujo oficial de Nexys A7.

## Alcance

- Top fisico: `star_tracker_top_arty_z7_10`.
- FPGA/SoC: `xc7z010clg400-1`.
- Entrada de reloj: `125 MHz` desde `SYSCLK` de Arty Z7.
- Reloj interno del core: `100 MHz`, generado por `artyz7_clk_125_to_100`.
- Core reutilizado: `Top/rtl/star_tracker_top.vhd`.
- Salida de imagen: paquete UART `STY1` igual que en Nexys.

## Diferencias respecto a Nexys

- El proyecto Arty Z7 no reemplaza al proyecto Nexys.
- La OV7670 usa los Pmod `JA` y `JB`.
- La salida UART PL se asigna a `CK_IO0`; usar un adaptador USB-serial externo de 3.3 V.
- El USB-UART integrado de Arty Z7 no se asume disponible directamente desde PL.

## Archivos principales

- `rtl/artyz7_clk_125_to_100.vhd`: MMCM para generar 100 MHz desde 125 MHz.
- `rtl/star_tracker_top_arty_z7_10.vhd`: wrapper de placa.
- `constraints/star_tracker_top_arty_z7_10.xdc`: pines para Arty Z7-10.
- `vivado_projects/create_star_tracker_top_arty_z7_10_project.tcl`: crea el `.xpr`.
- `vivado_projects/build_star_tracker_top_arty_z7_10_bitstream.tcl`: genera el `.bit`.

## Uso

Antes de crear el proyecto, Vivado debe tener instalado soporte para Zynq-7000. En esta PC,
la prueba inicial no encontro ningun part `xc7z010`/`xc7z020`, por lo que se debe agregar el
soporte de dispositivos Zynq-7000 desde el instalador de Vivado antes de generar el `.xpr`.

```powershell
vivado -mode batch -source "artyz7/vivado_projects/create_star_tracker_top_arty_z7_10_project.tcl"
```

El proyecto queda en:

```text
artyz7/vivado_projects/star_tracker_top_arty_z7_10/star_tracker_top_arty_z7_10.xpr
```
