# Core RBF FPGA configuration
- Copy fpga bitstream i.e ```baseline_a76_hps_debug.core.rbf``` at ```meta-custom/recipes-fpga/fpga-bitstream/files/```
    - rbf file name is users choice but make sure to update the file name using kas menu.
- Run ```kas menu``` command and select the ```Enable core RBF FPGA configuration``` option under ```FPGA options``` and Build.
```
FPGA options
 [*]  Enable core RBF FPGA configuration
 (baseline_a76_hps_debug.core.rbf) Core RBF configuration bitstream filename
```
- Run `kas menu` commad and build

[OR]

- Copy fpga bitstream i.e ```filename.core.rbf``` at ```meta-custom/recipes-fpga/fpga-bitstream/files/```
- Update following lines in `kas.yml`
    - `FPGA_ENABLE_CORE_PGM ?= "1"`
    - `FPGA_RBF_FILE ?= "filename.core.rbf"`
- Run `kas build kas.yml`

**Note:** 
- This option is applicable only for HPS boot first mode.
- To build fpga-bitstream recipe
    - `kas shell kas.yml`
    - `bitbake -c build fpga-bitstream`
- During the build, the baseline_a76_hps_debug.core.rbf file is installed to:
  ```build/tmp/work/<Machine Id>-poky-linux/fpga-bitstream/1.0/deploy-fpga-bitstream/```
  Meanwhile, the kernel recipe picks up this bitstream as needed and generates the combined kernel image kernel.itb.
