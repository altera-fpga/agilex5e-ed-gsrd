# NiosV demo Application

This is a demo application for the NiosV subsystem to generate traffic to the F2H and F2SDRAM bridge.

Make should be run in the design root folder, where quartus project is stored.

## Quick start

### Build the software
```bash
make niosv_fw-build
```

## Copy HEX file into the project root directory and sim directory
```bash
make niosv_fw-install
```

## Utility to clean the niosv build artifact
```bash
make niosv_fw-clean
```
