#!/usr/bin/env bash

SCRIPT=$(readlink -f $BASH_SOURCE)
top=$(readlink -f "$(dirname "$SCRIPT")")

export CONFIG_HABV4_TABLE_BIN=$top/cst/crts/SRK_1_2_3_4_table.bin 
export CONFIG_HABV4_IMG_CRT_PEM=$top/cst/crts/IMG1_1_sha256_4096_65537_v3_usr_crt.pem 
export CONFIG_HABV4_CSF_CRT_PEM=$top/cst/crts/CSF1_1_sha256_4096_65537_v3_usr_crt.pem 
#export CST=/home/hcl/Project/laerdal/sw/cstbuild/cst/code/obj.linux64/cst
