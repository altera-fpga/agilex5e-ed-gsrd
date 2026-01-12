/******************************************************************************
 *
 *   Copyright (C) 2025 Altera Corporation. All rights reserved.
 *
 *   SPDX-License-Identifier: GPL-2.0-only
 *
 *****************************************************************************/

#include <linux/module.h>

static int __init hello_module_init(void)
{
    pr_info("hello_module: Kernel module loaded successfully.\n");
    return 0;
}

static void __exit hello_module_exit(void)
{
    pr_info("hello_module: Kernel module unloaded. Goodbye!\n");
}

module_init(hello_module_init);
module_exit(hello_module_exit);
MODULE_LICENSE("GPL");
