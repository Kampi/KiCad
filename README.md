# KiCad

## Table of Contents

- [KiCad](#kicad)
  - [Table of Contents](#table-of-contents)
  - [About](#about)
  - [Setup](#setup)
  - [Directories](#directories)
  - [Maintainer](#maintainer)

### About

My private KiCad repository with symbols, 3D models (most of the models are delivered by the part manufacturer, [GrabCAD](https://grabcad.com/), [3D ContentCentral](https://www.3dcontentcentral.com/Default.aspx) or [SnapEDA](https://www.snapeda.com/)), and footprints for different projects.

Please write an e-mail to [DanielKampert@kampis-elektroecke.de](DanielKampert@kampis-elektroecke.de) if you have any questions.

## Setup

Download the repository and create a environment variable with the name `KICAD_LIBRARY`. Set the path of the variable to the location of the repository.

## Directories

The library contain the following directory and file structure:

- `3D` : All 3D models in `step` format used by the library
- `Drawings` : Inventor projects for different 3D models
- `Footprints` : Part footprints
- `Layout` : Layout templates
- `Scripts` : Python scripts for KiCad
- `Symbols` : Part symbols
- `__Project__` : Project template

## Maintainer

- [Daniel Kampert](mailto:DanielKampert@kampis-elektroecke.de)
