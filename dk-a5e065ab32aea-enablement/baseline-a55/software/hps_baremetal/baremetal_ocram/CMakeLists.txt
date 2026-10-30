cmake_minimum_required(VERSION 3.14...3.28)

# Baremetal config
set(PLAT            "agilex5" CACHE STRING "Target platform")
set(BUILD_MODE      "OCRAM"   CACHE STRING "Memory layout: OCRAM or DDR")

# Get the baremetal repo first so its CMake helpers are available before
# project() runs.
include(FetchContent)
FetchContent_Declare(
    baremetal
    GIT_REPOSITORY https://github.com/altera-fpga/baremetal-drivers.git
    GIT_TAG        66bdcc347564c5698a8997169bce83a31647d618 
)
FetchContent_GetProperties(baremetal)
if(NOT baremetal_POPULATED)
    FetchContent_Populate(baremetal)
endif()

# Cross-compile setup from the baremetal repo. Must be included before project().
# Skipped if the caller supplies its own toolchain/compiler.
if(NOT CMAKE_TOOLCHAIN_FILE AND NOT CMAKE_C_COMPILER)
    include("${baremetal_SOURCE_DIR}/cmake/bm_toolchain.cmake")
endif()

# Add project
project(hps_baremetal C ASM)

# Include baremetal
# EXCLUDE_FROM_ALL: only build baremetal targets that hps_baremetal.elf links
# against; prevents the library's own baremetal.elf from being built.
add_subdirectory("${baremetal_SOURCE_DIR}" "${baremetal_BINARY_DIR}" EXCLUDE_FROM_ALL)
add_executable(${PROJECT_NAME}.elf)

# Apply optimization / build flags
target_compile_options(${PROJECT_NAME}.elf PRIVATE
    # Prevent the compiler from substituting printf("literal\n") with puts(),
    # which has no implementation in this -nostdlib baremetal build.
    -fno-builtin-printf
)

# Generate .bin/.hex/.dump artifacts using the helper provided by the baremetal
# repo (cmake/bm_artifacts.cmake), so the logic lives in one place
include("${baremetal_SOURCE_DIR}/cmake/bm_artifacts.cmake")
bm_generate_artifacts(${PROJECT_NAME}.elf)

# Link to baremetal. Mirror the km-hps ELF's own library set; --start-group/
# --end-group resolves the cross-archive references between them. bm_app carries
# the freestanding lib/ (string/printf/parse/time), i.e. memcpy, memset, cstrcmp,
# lib_vprintf, parse_hex/parse_dec and clock_ticks/ticks_to_* used by bm_api.
target_link_libraries(${PROJECT_NAME}.elf PRIVATE
    -Wl,--start-group
    bm_app
    platform
    bm_api
    -Wl,--end-group
)

# Sources
target_sources(${PROJECT_NAME}.elf PRIVATE
    main.c
    "${baremetal_SOURCE_DIR}/src/crt0.c"
    "${baremetal_SOURCE_DIR}/src/startup.S"
    "${baremetal_SOURCE_DIR}/src/vectors.S"
    "${baremetal_SOURCE_DIR}/examples/hello/hello_selftest.c"
)

# hello_selftest.c pulls in examples/example_register.h and api/console/
# console_api.h -> lib_parse.h. km-hps sets include/ and lib/ globally for its
# own targets, but those don't propagate to this downstream target, so add them
# here alongside examples/ (api/ and platform/ come via the linked libraries).
target_include_directories(${PROJECT_NAME}.elf PRIVATE
    "${baremetal_SOURCE_DIR}/examples"
    "${baremetal_SOURCE_DIR}/lib"
)

# Set link options
# LD_SCRIPT is resolved from BUILD_MODE inside the baremetal library and
# exported via the CMake cache, so just reference it.
target_link_options(${PROJECT_NAME}.elf PRIVATE
    -T "${LD_SCRIPT}"
    -nostdlib
    -no-pie
    -Wl,-L${baremetal_SOURCE_DIR}
    -Wl,-Map=${CMAKE_BINARY_DIR}/${PROJECT_NAME}.map
)
