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
else
	C_ARG := CROSS_COMPILE=
	CC_ARG_OPTEE := CROSS_COMPILE64=
endif
OPTEE_ARGS := PLATFORM=imx-mx93evk
GITREF = $(shell git describe --tags --long --always --dirty)

FWBIN := firmware-imx-8.24-fbe0a4c
DDRFW := $(FWBIN)/firmware/ddr/synopsys
DDRFW_VERSION := v202201
ELE_FW := firmware-sentinel-0.11

RAUC_FILE := bootloader-$(GITREF).raucb

lpddr4_dmem_1d := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_dmem_1d_$(DDRFW_VERSION).bin
lpddr4_imem_1d := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_imem_1d_$(DDRFW_VERSION).bin
lpddr4_dmem_2d := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_dmem_2d_$(DDRFW_VERSION).bin
lpddr4_imem_2d := $(RPO)/firmware-imx/$(DDRFW)/lpddr4_imem_2d_$(DDRFW_VERSION).bin

BB_FW_DEPS := $(lpddr4_dmem_1d) $(lpddr4_dmem_1d) $(lpddr4_dmem_1d) $(lpddr4_imem_2d)

BL31 := imx93-bl31.bin
ATF_ARGS := PLAT=imx93 IMX_BOOT_UART_BASE=0x30890000 CROSS_COMPILE=$(CROSS_COMPILE)
BAREBOX_CONFIG ?= as_imx_defconfig

ifdef OPTEE
	OPTEE_DEP := barebox/firmware/imx93-bl32.bin
	BL31 := imx93-bl31.bin-optee
	ATF_ARGS := PLAT=imx93 IMX_BOOT_UART_BASE=0x30890000 SPD=opteed BL32_BASE=0xBE000000
endif


BB_IMAGES := $(RPO)/barebox/images/barebox-as93qsb.img
RAUC_IMAGES := $(BB_IMAGES)

all: $(BB_IMAGES)
rauc: $(RPO)/$(RAUC_FILE) Makefile
images: $(RAUC_IMAGES) Makefile

atf:
	make -C imx-atf BUILD_BASE=$(RPO)/atf $(ATF_ARGS) $(CC_ARG) -j

$(RPO)/atf/imx93/release/bl31.bin: atf

$(BB_IMAGES): $(RPO)/atf/imx93/release/bl31.bin $(OPTEE_DEP) $(BB_FW_DEPS) Makefile
	@cp $(RPO)/atf/imx93/release/bl31.bin barebox/firmware/$(BL31)
	@cp $(lpddr4_imem_1d) barebox/firmware/lpddr4_pmu_train_1d_imem.bin
	@cp $(lpddr4_dmem_1d) barebox/firmware/lpddr4_pmu_train_1d_dmem.bin
	@cp $(lpddr4_imem_2d) barebox/firmware/lpddr4_pmu_train_2d_imem.bin
	@cp $(lpddr4_dmem_2d) barebox/firmware/lpddr4_pmu_train_2d_dmem.bin
	make -C ./barebox ARCH=arm O=$(RPO)/barebox $(CC_ARG) $(BAREBOX_CONFIG)
	make -C ./barebox ARCH=arm O=$(RPO)/barebox $(CC_ARG) -j

$(BB_FW_DEPS): $(RPO)/firmware-imx/$(FWBIN)

$(RPO)/firmware-imx/$(FWBIN):
	@wget -P $(RPO)/firmware-imx https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/$(FWBIN).bin
	@chmod 0755 $(RPO)/firmware-imx/$(FWBIN).bin
	cd $(RPO)/firmware-imx; ./$(FWBIN).bin --auto-accept --force

$(RPO)/firmware-imx/$(ELE_FW):
	@wget -P $(RPO)/firmware-imx https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/$(ELE_FW).bin
	@chmod 0755 $(RPO)/firmware-imx/$(ELE_FW).bin
	cd $(RPO)/firmware-imx; ./$(ELE_FW).bin --auto-accept --force


$(RPO)/optee/core/tee-raw.bin:
	@echo "Build OPTEE using $(OPTEE_ARGS) $(CC_ARG_OPTEE)"
	make -C imx-optee-os O=$(RPO)/optee $(OPTEE_ARGS) $(CC_ARG_OPTEE) -j

barebox/firmware/imx93-bl32.bin: $(RPO)/optee/core/tee-raw.bin $(RPO)/firmware-imx/$(ELE_FW)
	@cp $< $@

$(RPO)/$(RAUC_FILE): manifest.raucm.in $(RAUC_IMAGES)
	rm -rf $(RPO)/tmp
	mkdir -p $(RPO)/tmp
	@sed -e 's:@VERSION@:$(GITREF):g' -e 's/@BUILD@/$(BUILDDATE)/g' < manifest.raucm.in > $(RPO)/tmp/manifest.raucm
	@cp $(RPO)/barebox/images/barebox-*.img $(RPO)/tmp
	rauc bundle --cert "$(RAUC_CERT_FILE)" --key "$(RAUC_KEY_FILE)"  $(RPO)/tmp $@

clean:
	make -C ./barebox clean
	make -C ./imx-atf clean
	make -C ./imx-optee-os clean
	rm -rf build/
