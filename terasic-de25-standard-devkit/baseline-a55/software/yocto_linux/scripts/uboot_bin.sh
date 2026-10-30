uboot_part_size=2*1024*1024
uboot_size=`wc -c < u-boot.itb`
uboot_pad="$((uboot_part_size-uboot_size))"
cp u-boot.itb u-boot.bin
truncate -s +$uboot_pad u-boot.bin
