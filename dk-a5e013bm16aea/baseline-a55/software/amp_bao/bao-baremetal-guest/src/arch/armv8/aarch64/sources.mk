## SPDX-License-Identifier: Apache-2.0
## Copyright (c) Bao Project and Contributors. All rights reserved.

arch_s_srcs+=$(addprefix $(ARCH_SUB)/, exceptions.S page_tables.S start.S)
