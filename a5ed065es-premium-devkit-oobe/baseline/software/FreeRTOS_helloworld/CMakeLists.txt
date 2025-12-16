cmake_minimum_required(VERSION 3.5...3.28)


include(FetchContent)

set(FREERTOS_FATFS n)
set(FREERTOS_USB n)
set(FREERTOS_TCPIP n)
set(FREERTOS_LIBRSU n)
set(FREERTOS_LIBFCS n)

FetchContent_Declare(
    freertos
    GIT_REPOSITORY https://github.com/Ignitarium-Technology/freertos-socfpga.git
    GIT_TAG main
)

# Get the freertos repo
FetchContent_MakeAvailable(freertos)

# project
project(freertos_hello_world C CXX ASM)

set(LINKER_SCRIPT "${freertos_SOURCE_DIR}/lscript.ld")
include(${freertos_SOURCE_DIR}/tools/target_socfpga.cmake)

# target
add_executable(${PROJECT_NAME}.elf)

#Add image generation
generate_bin_file(${PROJECT_NAME}.elf)

# link to the baremetal library
target_link_libraries(${PROJECT_NAME}.elf
    PRIVATE freertos_socfpga
)

# sources
target_sources(${PROJECT_NAME}.elf
    PRIVATE hello_world.c
)

# specify linker script
target_link_options(${PROJECT_NAME}.elf PRIVATE
   -T ${LINKER_SCRIPT}
)

