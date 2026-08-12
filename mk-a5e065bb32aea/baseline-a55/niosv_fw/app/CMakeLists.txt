cmake_minimum_required(VERSION 3.14)

add_subdirectory(../bsp bsp)

include(../bsp/toolchain.cmake)

project(niosv_app)

enable_language(ASM)
enable_language(C)
enable_language(CXX)

add_executable(niosv_app.elf)

target_sources(niosv_app.elf
    PRIVATE
        main.c
)

target_include_directories(niosv_app.elf
    PRIVATE
    PUBLIC
)

target_link_libraries(niosv_app.elf
    PRIVATE
        -T "${BspLinkerScript}" -nostdlib
        "${ExtraArchiveLibraries}"
        -Wl,--start-group "${BspLibraryName}" -lc -lstdc++ -lgcc -lm -Wl,--end-group
)

# Create objdump from ELF.
set(objdump niosv_app.elf.objdump)
add_custom_command(
    OUTPUT "${objdump}"
    DEPENDS niosv_app.elf
    COMMAND "${ToolchainObjdump}" "${ToolchainObjdumpFlags}" niosv_app.elf >
            "${objdump}"
    COMMENT "Creating ${objdump}."
    VERBATIM
)
add_custom_target(create-objdump ALL DEPENDS "${objdump}")

# Report space free for stack + heap. Note that the file below is never created
# so the report is always output on build.
set(stack_report_file niosv_app.elf.stack_report)
add_custom_command(
    OUTPUT "${stack_report_file}"
    DEPENDS niosv_app.elf
    COMMAND niosv-stack-report -p "${ToolchainPrefix}" niosv_app.elf
    COMMENT "Reporting memory available for stack + heap in niosv_app.elf."
    VERBATIM
)
add_custom_target(niosv-stack-report ALL DEPENDS "${stack_report_file}")

# Generate HEX file(s) from niosv_app.elf using elf2hex tool.
# Note : If ECC Full is enabled, width of 39 is set for NiosV TCM. Otherwise, 32.
add_custom_command(
    OUTPUT "u_niosv_onchip_memory.hex"
    DEPENDS niosv_app.elf
    COMMAND elf2hex niosv_app.elf -o u_niosv_onchip_memory.hex -b 0x00000000 -w 32 -e 0x0003FFFF -r 4
    COMMENT "Creating u_niosv_onchip_memory.hex."
    VERBATIM
)
add_custom_target(create-hex ALL DEPENDS "u_niosv_onchip_memory.hex")
