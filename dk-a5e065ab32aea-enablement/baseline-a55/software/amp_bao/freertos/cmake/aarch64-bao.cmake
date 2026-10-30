# aarch64-bao.cmake — CMake cross-compile toolchain for FreeRTOS-on-Bao guests
#
# Purpose
# -------
# Provides a CMake toolchain file pinned to the bare-metal `aarch64-none-elf-`
# triple that hps-amp installs under .toolchain/ via `make toolchains`.
#
# Usage
# -----
# Typical (orchestrator drives the build via `make CONFIG=... freertos`):
#   The orchestrator already prepends .toolchain/<...>-aarch64-none-elf/bin to
#   PATH, and the freertos-socfpga tree's own tools/target_socfpga.cmake
#   (included from each sample's CMakeLists.txt via FetchContent) sets the same
#   CMAKE_C_COMPILER vars in CACHE with FORCE. As a result the build configures
#   correctly without anyone passing -DCMAKE_TOOLCHAIN_FILE, and this file is
#   NOT used by default.
#
# Direct CMake invocation (if you ever bypass the orchestrator):
#   cmake -DCMAKE_TOOLCHAIN_FILE=/abs/path/to/hps-amp/cmake/aarch64-bao.cmake \
#         -DBAO_GUEST=ON -DBAO_LOAD_ADDR=0x90000000 -DBAO_MEM_SIZE=0x04000000 \
#         -S <freertos-socfpga-sample> -B <build>
#   In that case this file pins the compiler BEFORE project() runs, which is
#   the canonical CMake cross-compile setup. target_socfpga.cmake still runs
#   afterwards and re-asserts the same values via CACHE FORCE — the two are
#   deliberately consistent so neither overrides the other in surprising ways.

set(CMAKE_SYSTEM_NAME      Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CC_PREFIX aarch64-none-elf-)

set(CMAKE_C_COMPILER   ${CC_PREFIX}gcc)
set(CMAKE_ASM_COMPILER ${CC_PREFIX}gcc)
set(CMAKE_CXX_COMPILER ${CC_PREFIX}g++)
set(CMAKE_AR           ${CC_PREFIX}ar      CACHE FILEPATH "")
set(CMAKE_OBJCOPY      ${CC_PREFIX}objcopy CACHE FILEPATH "")
set(CMAKE_OBJDUMP      ${CC_PREFIX}objdump CACHE FILEPATH "")

# Bare-metal — try_compile() with an executable fails because newlib's _exit/_sbrk
# aren't linkable without the platform's specs file. Build static lib instead.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Cross-compiling: don't search host system for libraries / headers.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
