# Ubuntu HOWTO for SoCFPGA

This document provides instructions on how to put together an SD card
image for Agilex 5 to run Ubuntu.

## Disclaimer

Altera provides these materials to our customers solely as an example of
how a Linux operating system may be configured for use with Altera products.
Altera does not endorse, certify, or support Ubuntu or any other third-party
operating system or software. It is the customer’s sole responsibility to
determine whether Ubuntu, or another Linux instance is appropriate for its
intended use, and to ensure compliance with all applicable open-source licenses,
security requirements and technical or regulatory obligations.
Altera offers these instructions “AS-IS” without any warranty of any kind,
whether express, implied statutory or otherwise and Altera will not be liable
to customer under any legal theory related to customer’s choice in using or
distributing Ubuntu.

## Running the script

Run **mk_ubuntu_sd.sh** to build all components (ATF, U-Boot, kernel) and to
assemble an SD card image with the Ubuntu root file system

run **./mk_ubuntu_sd.sh -h** to see options.

## Recommendations and Assumptions

We recommend running the script on Ubuntu 22.04 or later. The script requires
the following packages to be installed prior to running the script:

build-essential, bison, flex, guestfs-tools, u-boot-tools, python3-setuptools,
python3-dev, libssl-dev, bc, qemu-user-static, xz-utils, wget, sudo, swig

This can be achieved via:

$ sudo apt update
$ sudo apt install -y build-essential bison flex      \
                      guestfs-tools u-boot-tools      \
                      python3-setuptools python3-dev  \
                      libssl-dev bc qemu-user-static  \
                      xz-utils wget sudo swig git     \
 		      systemd-timesyncd

Also, the utility 'guestfish' requires access to the machine's kernel file,
located in /boot on Ubuntu. Make sure this file is readable by all users.
Otherwise, the guestfish command 'run' will fail.
