# Build Bareox with firmware embedded

O ?= $(PWD)/build
TOP := $(PWD)
RPO = $(shell realpath $O)
 
CONFIG_HABV4_TABLE_BIN ?= $(TOP)/cst/crts/SRK_1_2_3_4_table.bin
CONFIG_HABV4_IMG_CRT_PEM ?= $(TOP)/cst/crts/IMG1_1_sha256_4096_65537_v3_usr_crt.pem 
CONFIG_HABV4_CSF_CRT_PEM ?= $(TOP)/cst/crts/CSF1_1_sha256_4096_65537_v3_usr_crt.pem 

export CONFIG_HABV4_TABLE_BIN
export CONFIG_HABV4_IMG_CRT_PEM
export CONFIG_HABV4_CSF_CRT_PEM

arch := $(shell uname -m)
$(info host arch is $(arch))
BUILDDATE := $(shell date -u +%F:%H:%M)
$(info BUILDTIME $(BUILDDATE))
ifneq ($(arch),aarch64)
	CC_ARG := CROSS_COMPILE=aarch64-linux-gnu-
	CC_ARG_OPTEE := CROSS_COMPILE64=aarch64-linux-gnu-
endif

GITREF = $(shell git describe --tags --long --always --dirty)

FWBIN := firmware-imx-8.24-fbe0a4c
DDRFW := $(FWBIN)/firmware/ddr/synopsys
DDRFW_VERSION := 202006

RAUC_FILE := bootloader-$(GITREF).raucb

BB_FW_DEPS1 := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_pmu_train_1d_dmem_$(DDRFW_VERSION).bin
BB_FW_DEPS2 := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_pmu_train_1d_imem_$(DDRFW_VERSION).bin
BB_FW_DEPS3 := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_pmu_train_2d_dmem_$(DDRFW_VERSION).bin
BB_FW_DEPS4 := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_pmu_train_2d_imem_$(DDRFW_VERSION).bin

BB_FW_DEPS := $(BB_FW_DEPS1) $(BB_FW_DEPS2) $(BB_FW_DEPS3) $(BB_FW_DEPS4)

BL31 := imx93-bl31.bin
ATF_ARGS := PLAT=imx93 IMX_BOOT_UART_BASE=0x30890000 CROSS_COMPILE=$(CROSS_COMPILE)
BAREBOX_CONFIG ?= as_imx_defconfig
ifdef OPTEE
	EXTRADEP := barebox/firmware/imx93-bl32.bin
	BL31 := imx93-bl31.bin-optee
	ATF_ARGS := PLAT=imx93 IMX_BOOT_UART_BASE=0x30890000 SPD=opteed BL32_BASE=0xBE000000
endif

RAUC_IMAGES := $(RPO)/barebox/stripped/barebox-as93evk.img

BB_IMAGES := $(RPO)/barebox/images/barebox-as93evk.img

all: $(RAUC_IMAGES)
rauc: $(RPO)/$(RAUC_FILE) Makefile

images: $(RAUC_IMAGES) Makefile

atf:
	make -C imx-atf BUILD_BASE=$(RPO)/atf $(ATF_ARGS) $(CC_ARG) -j

$(RPO)/atf/imx93/release/bl31.bin: atf

$(RPO)/barebox/stripped/barebox-as93evk.img: $(RPO)/atf/imx93/release/bl31.bin $(EXTRADEP) $(BB_FW_DEPS) Makefile
	@cp $(RPO)/atf/imx93/release/bl31.bin barebox/firmware/$(BL31)
	@cp $(BB_FW_DEPS1) barebox/firmware/lpddr4_pmu_train_1d_dmem.bin
	@cp $(BB_FW_DEPS2) barebox/firmware/lpddr4_pmu_train_1d_imem.bin
	@cp $(BB_FW_DEPS3) barebox/firmware/lpddr4_pmu_train_2d_dmem.bin
	@cp $(BB_FW_DEPS4) barebox/firmware/lpddr4_pmu_train_2d_imem.bin
	make -C ./barebox ARCH=arm O=$(RPO)/barebox $(CC_ARG) $(BAREBOX_CONFIG)
	make -C ./barebox ARCH=arm O=$(RPO)/barebox $(CC_ARG) -j
	mkdir -p $(RPO)/barebox/stripped
	@dd if=$(RPO)/barebox/images/barebox-as93evk.img of=$(RPO)/barebox/stripped/barebox-as93evk.img bs=1024 skip=32


$(BB_FW_DEPS): $(RPO)/firmware-imx/$(FWBIN)

$(RPO)/firmware-imx/$(FWBIN):
	@wget -P $(RPO)/firmware-imx https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/$(FWBIN).bin
	@chmod 0755 $(RPO)/firmware-imx/$(FWBIN).bin
	cd $(RPO)/firmware-imx; ./$(FWBIN).bin --auto-accept --force

$(RPO)/optee/core/tee-raw.bin:
	make -C imx-optee-os O=$(RPO)/optee CFG_OPTEE_CONFIG="$(TOP)/optee.cfg" $(CC_ARG_OPTEE) -j

barebox/firmware/imx93-bl32.bin: $(RPO)/optee/core/tee-raw.bin
	@cp $< $@ 

$(RPO)/$(RAUC_FILE): manifest.raucm.in $(RAUC_IMAGES)
	rm -f $@
	@sed -e 's:@VERSION@:$(GITREF):g' -e 's/@BUILD@/$(BUILDDATE)/g' < manifest.raucm.in > $(RPO)/barebox/stripped/manifest.raucm
	rauc bundle --cert "$(RAUC_CERT_FILE)" --key "$(RAUC_KEY_FILE)"  $(RPO)/barebox/stripped $@

clean:
	make -C ./barebox clean
	make -C ./imx-atf clean
	make -C ./imx-optee-os clean
	rm -rf build/
