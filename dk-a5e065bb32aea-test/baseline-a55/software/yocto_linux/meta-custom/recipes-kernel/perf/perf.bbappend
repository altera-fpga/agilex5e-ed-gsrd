# Fix for perf build on arm64 with Linux 6.18+
# Upstream fix: https://github.com/openembedded/openembedded-core/commit/7e24a0e9dd75070bff0c11c4db47a30b71afaa94
#
# Kernel commit bfb713ea53c7 ("perf tools: Fix arm64 build by generating unistd_64.h")
# introduces a new dependency on include/uapi/asm-generic source files for arm64.
#
# Build fails with:
# scripts/Makefile.asm-headers:33: include/uapi/asm-generic/Kbuild: No such file or directory
# make[4]: *** No rule to make target 'include/uapi/asm-generic/Kbuild'.  Stop.

PERF_SRC:append = " \
    include/uapi/asm-generic/Kbuild \
"
