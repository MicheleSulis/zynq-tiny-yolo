# Zynq Tiny YOLO

Bare-metal firmware and custom RTL blocks for a FINN-based
YOLOv3-Tiny accelerator on Zynq-7020.

## Project structure

`board-projects` follows the development stages, from firmware
bring-up and DMA loopback to FINN integration and RTL MaxPool.

- `firmware`: bare-metal C and assembly code.
- `hardware`: RTL sources, testbenches, bitstreams and hardware exports.
- `software`: host-side image preparation and result processing.

Vivado projects were developed using version 2022.2.

FINN network is based on the work of
[Calì et al.](https://doi.org/10.3390/electronics14203993)

## Vivado projects

Complete Vivado project archives, including available synthesis and
implementation results, are available in the [release](https://github.com/MicheleSulis/zynq-tiny-yolo/releases/tag/v1.0).

## License

Original code and contributions by Michele Sulis are licensed under
[BSD-3-Clause](LICENSE). Third-party code retains its original copyright
notices and licenses, including [Apache-2.0](LICENSE-APACHE-2.0.txt)
for Arm/CMSIS components.
