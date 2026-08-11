cmake_minimum_required(VERSION 3.5...3.28)

# FreeRTOS config
set(PFG_QSPI "null" CACHE STRING "PFG path")
set(SOF_PATH "null" CACHE STRING "SOF File path")
set(FREERTOS_FATFS n)
set(FREERTOS_USB n)
set(FREERTOS_TCPIP n)
set(FREERTOS_LIBRSU n)
set(FREERTOS_LIBFCS n)

# Get the freertos repo
include(FetchContent)
FetchContent_Declare(
    freertos
    GIT_REPOSITORY https://github.com/Ignitarium-Software/freertos-socfpga
    GIT_TAG 7000df2db62f270551789f04673133baf115482b
)
FetchContent_MakeAvailable(freertos)
FetchContent_GetProperties(freertos)

# Add executable
project(datamover C CXX ASM)

# Include freertos
set(LINKER_SCRIPT "${freertos_SOURCE_DIR}/lscript.ld")
include(${freertos_SOURCE_DIR}/tools/target_socfpga.cmake)
add_executable(${PROJECT_NAME}.elf)

# Apply optimization flag -O3
target_compile_options(${PROJECT_NAME}.elf PRIVATE -O3)

# Generate binary
generate_bin_file(${PROJECT_NAME}.elf)

if (DM_VERSION STREQUAL "single-threaded")
    # link to the freertos libraries and the data mover task library
    target_link_libraries(${PROJECT_NAME}.elf
        PRIVATE
        freertos_socfpga
    )
    # link data mover directories
    target_include_directories(${PROJECT_NAME}.elf
        PRIVATE
        ${CMAKE_SOURCE_DIR}/
        single-threaded/datamover_tasks/
        fabric_dmac/
    )
    # code sources
    target_sources(${PROJECT_NAME}.elf
        PRIVATE
        single-threaded/main.c
        single-threaded/datamover_tasks/f2h_task.c
        single-threaded/datamover_tasks/f2sdram_task.c
        single-threaded/datamover_tasks/s2s_dma_task.c
        single-threaded/datamover_tasks/s2s_task.c
        fabric_dmac/fabric_dmac.c
    )
elseif(DM_VERSION STREQUAL "multi-threaded")
    # link to the freertos libraries
    target_link_libraries(${PROJECT_NAME}.elf
        PRIVATE
        freertos_socfpga
    )
    # link data mover directories
    target_include_directories(${PROJECT_NAME}.elf
        PRIVATE
        ${CMAKE_SOURCE_DIR}/
        multi-threaded/datamover_tasks/
        fabric_dmac/
        qos_generator/
    )
    # code sources
    target_sources(${PROJECT_NAME}.elf
        PRIVATE
        multi-threaded/main.c
        multi-threaded/datamover_tasks/f2h_task.c
        multi-threaded/datamover_tasks/f2sdram_task.c
        multi-threaded/datamover_tasks/s2s_task.c
        multi-threaded/datamover_tasks/s2s_dma_task.c
        fabric_dmac/fabric_dmac.c
        qos_generator/qos_generator.c
    )
else()
    message(FATAL_ERROR "Invalid DM_VERSION specified. Please choose either 'single-threaded' or 'multi-threaded'.")
endif()

# Set link options
target_link_options(${PROJECT_NAME}.elf PRIVATE -T "${LINKER_SCRIPT}")

set(FPGA_BINARIES_DIR "${CMAKE_BINARY_DIR}/fpga_binaries")

# Derive objcopy from the C compiler's toolchain directory so it works
# without relying on PATH at build time
get_filename_component(_TOOLCHAIN_DIR "${CMAKE_C_COMPILER}" DIRECTORY)
find_program(AARCH64_OBJCOPY
    NAMES aarch64-none-elf-objcopy
    HINTS "${_TOOLCHAIN_DIR}"
    REQUIRED
)

# Copy bl2.bin and bl31.bin from qspi_atf_binaries (ATF output) into fpga_binaries
add_custom_command(
    OUTPUT "${FPGA_BINARIES_DIR}/bl2.bin" "${FPGA_BINARIES_DIR}/bl31.bin"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${FPGA_BINARIES_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${QSPI_ARTIFACTS_DIR}/bl2.bin" "${FPGA_BINARIES_DIR}/bl2.bin"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${QSPI_ARTIFACTS_DIR}/bl31.bin" "${FPGA_BINARIES_DIR}/bl31.bin"
    DEPENDS atf-bl2-bl31-qspi
    COMMENT "Copying ATF binaries to fpga_binaries"
)

# Convert bl2.bin -> bl2.hex (needed to embed BL2 into the FPGA SOF)
add_custom_command(
    OUTPUT "${FPGA_BINARIES_DIR}/bl2.hex"
    COMMAND ${AARCH64_OBJCOPY}
            -I binary -O ihex --change-addresses 0x0
            "${FPGA_BINARIES_DIR}/bl2.bin"
            "${FPGA_BINARIES_DIR}/bl2.hex"
    DEPENDS "${FPGA_BINARIES_DIR}/bl2.bin"
    COMMENT "Generating bl2.hex"
)

add_custom_target(generate-bl2-hex ALL
    DEPENDS "${FPGA_BINARIES_DIR}/bl2.hex"
)

# datamover.elf depends on ATF targets being built first
add_dependencies(${PROJECT_NAME}.elf atf-bl2-bl31-qspi atf-fiptool)

# Package BL31 + datamover.bin into a Firmware Image Package (fip.bin)
add_custom_command(
    OUTPUT "${FPGA_BINARIES_DIR}/fip.bin"
    COMMAND "${CMAKE_BINARY_DIR}/fiptool" create
            --soc-fw "${FPGA_BINARIES_DIR}/bl31.bin"
            --nt-fw  "${CMAKE_BINARY_DIR}/datamover.bin"
            "${FPGA_BINARIES_DIR}/fip.bin"
    DEPENDS "${FPGA_BINARIES_DIR}/bl31.bin" atf-fiptool ${PROJECT_NAME}.elf
    COMMENT "Generating fip.bin"
)

add_custom_target(generate-fip ALL
    DEPENDS "${FPGA_BINARIES_DIR}/fip.bin"
)
