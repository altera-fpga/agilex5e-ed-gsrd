cmake_minimum_required(VERSION 3.5...3.28)

# rpmsg_console -- RPMsg-over-OpenAMP FreeRTOS guest (Bao AMP demo).
# ---------------------------------------------------------------
# Builds OpenAMP + libmetal as static archives inside the FreeRTOS CMake
# graph. After Linux writes DRIVER_OK the producer task creates an rpmsg
# endpoint ("rpmsg-raw") with NS_ANNOUNCE so /dev/rpmsg0 appears on the
# Linux side, then emits periodic heartbeat and ILC latency lines.
#
# Under BAO_GUEST the SOF/PFG and SD/QSPI bake steps are skipped --
# Bao boots the raw .bin directly via U-Boot (no Quartus toolchain on
# the build host).
if(NOT DEFINED FREERTOS_SOCFPGA_DIR)
    message(FATAL_ERROR
        "rpmsg_console needs -DFREERTOS_SOCFPGA_DIR=... "
        "(path to the freertos-socfpga checkout).")
endif()

if(NOT BAO_GUEST)
    include(${FREERTOS_SOCFPGA_DIR}/FreeRTOS/Demo/SOCFPGA/apps/download_dep.cmake)
endif()

include(FetchContent)

set(FREERTOS_FATFS n)
set(FREERTOS_USB n)
set(FREERTOS_TCPIP n)
set(FREERTOS_LIBRSU n)
set(FREERTOS_LIBFCS n)

FetchContent_Declare(
    freertos
    SOURCE_DIR ${FREERTOS_SOCFPGA_DIR}
)
FetchContent_MakeAvailable(freertos)

project(freertos_rpmsg_console C CXX ASM)

set(LINKER_SCRIPT "${freertos_SOURCE_DIR}/lscript.ld")
include(${freertos_SOURCE_DIR}/tools/target_socfpga.cmake)

add_executable(${PROJECT_NAME}.elf)
generate_bin_file(${PROJECT_NAME}.elf)
if(NOT BAO_GUEST)
    add_sd_image(${PROJECT_NAME}.elf)
    add_qspi_image(${PROJECT_NAME}.elf)
endif()

target_include_directories(${PROJECT_NAME}.elf PUBLIC
    ${FREERTOS_SOCFPGA_DIR}/FreeRTOS/Demo/SOCFPGA/apps/samples/Common/include
    ${CMAKE_CURRENT_SOURCE_DIR}/
    ${CMAKE_CURRENT_SOURCE_DIR}/libmetal_bao/
)

# Vendored OpenAMP + libmetal -- supplied by the hps-amp orchestrator
# Makefile via -DOPENAMP_SRC_DIR= / -DLIBMETAL_SRC_DIR= when
# SAMPLE_INST_0 == rpmsg_console. Both vars MUST be set for this sample
# (the rpmsg traffic path depends on the libraries); if either is
# missing, fail loudly at configure time instead of producing a build
# that links but silently no-ops the rpmsg path.
if(NOT DEFINED OPENAMP_SRC_DIR OR NOT DEFINED LIBMETAL_SRC_DIR)
    message(FATAL_ERROR
        "rpmsg_console needs -DOPENAMP_SRC_DIR=... -DLIBMETAL_SRC_DIR=... "
        "(orchestrator passes these for SAMPLE_INST_0=rpmsg_console).")
endif()

# libmetal: machine = bao, system = freertos. We override PROJECT_SYSTEM
# directly because target_socfpga.cmake sets CMAKE_SYSTEM_NAME=Generic
# (so it disables host-side test compiles); without this override
# libmetal's options.cmake would default PROJECT_SYSTEM to "generic"
# and our freertos/bao port would not be picked up.
set(MACHINE bao)
set(PROJECT_SYSTEM freertos)
set(PROJECT_SYSTEM_UPPER FREERTOS)
set(WITH_DOC OFF CACHE BOOL "" FORCE)
set(WITH_TESTS OFF CACHE BOOL "" FORCE)
set(WITH_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WITH_DEFAULT_LOGGER OFF CACHE BOOL "" FORCE)
set(WITH_SHARED_LIB OFF CACHE BOOL "" FORCE)
set(WITH_STATIC_LIB ON CACHE BOOL "" FORCE)
add_subdirectory(${LIBMETAL_SRC_DIR} ${CMAKE_BINARY_DIR}/libmetal)

# OpenAMP: skip find_package(Libmetal) (we already added libmetal as a
# sibling sub-project above); switch off proxy / docs.
#
# WITH_DCACHE=ON is critical: it defines VIRTIO_USE_DCACHE so OpenAMP's
# RSC_TABLE_INVALIDATE / RSC_TABLE_FLUSH / vring + buffer cache hooks
# turn into real `dc ivac` / `dc cvac` operations (via libmetal's
# metal_machine_cache_invalidate / _flush in our freertos/bao port).
# Without it those macros expand to no-ops and the FreeRTOS-side busy-
# poll on fw_rsc_vdev.status reads stale L1 D$ data forever, never
# observing the DRIVER_OK Linux writes from the other VM. Same logic
# applies to the vring descriptor / used-ring updates and the rpmsg
# buffer payloads -- all three live in shmem that needs explicit
# clean+invalidate at the producer/consumer boundary on Cortex-A55
# cross-VM (Bao stage-2 cacheable WB, but our two guests do not share
# an inner-shareable cache domain in all corner cases). Cheaper than
# bisecting a cache-coherence bug at runtime.
set(WITH_LIBMETAL_FIND OFF CACHE BOOL "" FORCE)
set(WITH_PROXY         OFF CACHE BOOL "" FORCE)
set(WITH_DOC           OFF CACHE BOOL "" FORCE)
set(WITH_SHARED_LIB    OFF CACHE BOOL "" FORCE)
set(WITH_STATIC_LIB    ON  CACHE BOOL "" FORCE)
set(WITH_DCACHE        ON  CACHE BOOL "" FORCE)
add_subdirectory(${OPENAMP_SRC_DIR}  ${CMAKE_BINARY_DIR}/openamp)

# Both libmetal and OpenAMP build a metal-static / open_amp-static
# target; libmetal places its generated <metal/...> headers under
# ${CMAKE_BINARY_DIR}/libmetal/lib/include after configure_file()
# expands the @PROJECT_SYSTEM@ / @PROJECT_MACHINE@ templates.
target_include_directories(${PROJECT_NAME}.elf PUBLIC
    ${CMAKE_BINARY_DIR}/libmetal/lib/include
    ${LIBMETAL_SRC_DIR}/lib/include
    ${OPENAMP_SRC_DIR}/lib/include
)
target_include_directories(metal-static PUBLIC
    ${CMAKE_BINARY_DIR}/libmetal/lib/include
    ${LIBMETAL_SRC_DIR}/lib/include
)
target_include_directories(open_amp-static PUBLIC
    ${CMAKE_BINARY_DIR}/libmetal/lib/include
    ${LIBMETAL_SRC_DIR}/lib/include
    ${OPENAMP_SRC_DIR}/lib/include
)

# Compile OpenAMP/libmetal against FreeRTOS-Kernel headers (used by
# libmetal's freertos/time.c -> #include <FreeRTOS.h>, <task.h>, plus
# libmetal's mutex.h / alloc.h / condition.h which pull in FreeRTOS.h
# transitively). PUBLIC so the FreeRTOS-Kernel includes propagate
# through metal-static -> open_amp-static -> our app target.
target_link_libraries(metal-static     PUBLIC freertos_kernel)
target_link_libraries(open_amp-static  PUBLIC metal-static)

target_sources(${PROJECT_NAME}.elf
    PRIVATE
    main.c
    main_rpmsg_console.c
    platform.c
    resource_table.c
    libmetal_bao/metal_bao.c
    # ILC interrupt-latency producer: ISR + drain task surfacing samples
    # on the rpmsg-raw channel. See ilc_latency.h for the pipeline contract.
    ilc_latency.c
    # GPIO LED driver: hps_led0 + hps_led1 toggle from the ILC drain task
    # so the ~4 s Interval Timer cadence is visible on the board LEDs.
    drivers/gpio/gpio_led.c
)

target_link_libraries(${PROJECT_NAME}.elf
    PRIVATE freertos_socfpga open_amp-static metal-static
)

target_link_options(${PROJECT_NAME}.elf PRIVATE
    -T ${LINKER_SCRIPT}
)

# Propagate the Bao guest IPA window into the linker script via --defsym.
# Root-scope add_link_options() from the FreeRTOS SoC-FPGA tree does not
# propagate to this app because the app imports that tree via FetchContent.
if(BAO_GUEST)
    target_link_options(${PROJECT_NAME}.elf PRIVATE
        "LINKER:--defsym=HV_GUEST_LOAD_ADDR=${HV_GUEST_LOAD_ADDR}"
        "LINKER:--defsym=HV_GUEST_MEM_SIZE=${HV_GUEST_MEM_SIZE}"
    )
endif()
