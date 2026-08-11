# Settings for ubifs
MKUBIFS_ARGS ?= "--leb-size 126976 --min-io-size 2048 --max-leb-cnt 7700"
UBINIZE_ARGS ?= "--peb-size 128KiB --min-io-size 2048 --sub-page-size 2048"
MULTIUBI_BUILD += "nand"
MKUBIFS_ARGS_nand ?= "--leb-size 126976 --min-io-size 2048 --max-leb-cnt 7700"
UBINIZE_ARGS_nand ?= "--peb-size 128KiB --min-io-size 2048 --sub-page-size 2048"
MULTIUBI_BUILD += "nor"
MKUBIFS_ARGS_nor ?= "-F -e 65408 -m 1 -c 7700"
UBINIZE_ARGS_nor ?= "-p 65536 -m 1 -s 1"

