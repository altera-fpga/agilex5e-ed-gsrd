# Data Mover FreeRTOS Software Programs

Data Mover FreeRTOS software programs run on the Agilex 5 HPS and orchestrate data transactions between FPGA fabric and external SDRAM and provide a framework for benchmarking memory transfer performances.

### Data Flows
There are 4 types of data transactions in this design example:

- **FPGA-to-HPS (F2H)**: showcases data transactions from fabric to external memory through the F2H bridge. Data undergoes cache-coherent mechanisms in the HPS before arriving at external memory.
- **FPGA-to-SDRAM (F2SDRAM)**: showcases data transactions from fabric to external memory through the F2SDRAM bridge. Data transfers occur directly between fabric and external memory, bypassing the HPS.
- **SDRAM-to-SDRAM (S2S) DMA**: showcases data transactions between different regions in external memory orchestrated by the Synopsys AXI Direct Memory Access Controllers (DMACs) in the HPS.
- **SDRAM-to-SDRAM (S2S) non-DMA**: showcases data transactions between different regions in external memory orchestrated by CPU read/write accesses.

F2H and F2SDRAM data transactions follows a similar flow that uses the respective fabric-HPS bridge as data path for COPY operation:

1. DMA controller reads a 524288-byte data block from source buffer in SDRAM
2. DMA controller writes the 524288-byte data block to OCM
3. DMA controller reads the 524288-byte data block from OCM
4. DMA controller writes the 524288-byte data block to destination buffer in SDRAM
5. DMA controller repeats Step 1 to 4 for all 524288-byte data blocks in a 20MB source buffer until all data get copied to a 20MB destination buffer.

S2S DMA transactions follow this flow:

1. DMA controller reads a 524288-byte data block from source buffer in SDRAM
2. DMA controller writes the 524288-byte data block to destination buffer in SDRAM
3. DMA controller repeats Step 1 to 2 for all 524288-byte data blocks in a 20MB source buffer until all data get copied to a 20MB destination buffer.

S2S non-DMA transactions involves simple arr_2[i] = arr_1[i] for all i's in two 524288-byte arr_1 and arr_2 arrays.

The FreeRTOS program initiates F2H and F2SDRAM data transactions by configuring mSGDMA IPs in the F2H DMAC subsystem and F2SDRAM DMAC subsytem, respectively. Details about the mSGDMA programming model can be found in the [Data Mover User Guide](https://docs.altera.com/r/example-designs/gg00091/current). The program initiates S2S DMA transactions by configuring the Synopsys AXI DMACs in the Agilex 5 HPS. Notably, the program configures all 4 data channels in each of the 2 DMACs - for a total of 8 data channels - to simultaneously execute data transactions. Details about the Synopsys DMAC programming model can also be found in the [Data Mover User Guide](https://docs.altera.com/r/example-designs/gg00091/current).

### Program Version and Configurability

This design consists of a single-threaded data transaction demonstration and a multi-threaded data transaction demonstration. The single-threaded program runs each of the 4 different data flows sequentially, allowing for maximum utilization of the HPS-memory DDR4 interface in each case. It showcases the best memory transaction performance results for F2H, F2SDRAM, and DDR2DDR data flows. The multi-threaded program showcases how to configure QoS generator for different data channels, how to run different data flows concurrently with FreeRTOS multi-threading, and demonstrates performance impact.

The table below highlights software configurations that could impact data transaction performance:

<table>
  <thead>
    <tr>
      <th>Program</th>
      <th>Parameter</th>
      <th>Where to Change</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="3">single-threaded</td>
      <td>transaction duration</td>
      <td>single-threaded/main.c</td>
    </tr>
    <tr>
      <td>memory buffer size (increase by increasing # of transfer blocks)</td>
      <td>single-threaded/datamover_tasks/datamover_tasks.h</td>
    </tr>
    <tr>
      <td>transfer block size (currently set as OCM size which is the max possible value)</td>
      <td>single-threaded/datamover_tasks/datamover_tasks.h</td>
    </tr>
    <tr>
      <td rowspan="5">multi-threaded</td>
      <td>transaction duration</td>
      <td>multi-threaded/main.c</td>
    </tr>
    <tr>
      <td>memory buffer size (increase by increasing # of transfer blocks)</td>
      <td>multi-threaded/datamover_tasks/datamover_tasks.h</td>
    </tr>
    <tr>
      <td>transfer block size (currently set as OCM size which is the max possible value)</td>
      <td>multi-threaded/datamover_tasks/datamover_tasks.h</td>
    </tr>
    <tr>
      <td>QoS generator values*</td>
      <td>multi-threaded/main.c</td>
    </tr>
    <tr>
      <td>Symmetric Multiprocessing (SMP) on/off</td>
      <td>build.sh</td>
    </tr>
  </tbody>
</table>

* Refer to [Data Mover User Guide](https://docs.altera.com/r/example-designs/gg00091/current) for more details on which QoS generator controls which data path.

# Performance Monitor IPs

On the host machine, a continuously-running PMON TCL program monitors data channel performance metrics in real-time (pmon_read). The program can capture different metrics by specifying different configurations. A detailed list of available metrics can be found in the [Performance Monitor FPGA IP User Guide](https://docs.altera.com/r/docs/817760/25.1.1/performance-monitor-fpga-ip-user-guide-agilextm-3-agilextm-5-and-agilextm-7-fpgas/performance-monitor-pmon-library-functions).

# Build Steps

The expected output of the build process is a JIC file that combines the FPGA bitstream and software binaries that users can program onto the FPGA board with quartus_pgm. The JIC file will contain components laid out in the [QSPI flash PFG file](../qspi_flash_image_agilex5_boot.pfg).

1. Enter the datamover folder

```bash
cd TOP_DIR/dk-a5e065ab32aea-enablement/datamover
```

2. Generate JIC file (XX-datamover.hps.jic)

```bash
make software-freertos_datamover-build-sw
```

st-datamover.hps.jic (single-threaded version) and mt-datamover.hps.jic (multi-threaded version) should appear under the software/freertos/datamover-app directory

Note: if you want to build just one of single-threaded or multi-threaded version, run

```bash
./software/freertos/datamover-app/build.sh $VERSION_NAME
```

where $VERSION_NAME is either "single-threaded" or "multi-threaded" or

```bash
make software-freertos_datamover-build-XX-sw
```

where XX is either "st" or "mt".

3. Program the board with JIC file

```bash
quartus_pgm -m jtag -c 1 -o "pvi;XX-datamover.hps.jic@2"
```

(Refer to the [Quartus Programmer Guide](https://docs.altera.com/r/docs/683039/25.3.1/quartus-prime-pro-edition-user-guide-programmer/scripting-support?tocId=hENJN1rgd6fRQEkgsuUfGQ) for more details on quartus_pgm options)

4. Power Cycle the FPGA board
5. Program outputs can be viewed through Serial Terminal Connection

# (Optional) Viewing Performance Monitor Outputs

You can view PMON Outputs in real-time by opening a separate System Console terminal. To ensure that the PMON has enough time to set up after the Data Mover design is loaded onto the board, we recommend setting longer transaction duration for data transaction tasks
(eg. 30 seconds each).

1. Open a separate terminal
2. Enter the datamover directory

```bash
cd TOP_DIR/dk-a5e065ab32aea-enablement/datamover
```

3. Open a System Console terminal

```bash
system-console --cli
```

4. Ensure that power cycle (Step 4 in Build Steps) completes
5. Run the PMON script inside System Console

```bash
source pmon/datamover_pmon.tcl
```

Note: PMON access is only available after FPGA bitstream configuration. Otherwise you might see the following error message:

```bash
Error : Performance Monitor remote JTAG interface not found
Ensure .sof is loaded and JTAG access is functional before loading Performance Monitor System console library
PMON Library loaded
invalid command name "pmon_discover_all"
    while executing
"pmon_discover_all"
```

In such scenario, close system-console, power cycle the board again, and give a bit more time before starting System Console and executing the PMON script again.