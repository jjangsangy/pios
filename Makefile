.SUFFIXES:
.SUFFIXES: .img.xz .zip
.DEFAULT_GOAL: extract

SHELL := /bin/bash

INFO_URL := https://changelogs.ubuntu.com/raspi/os_list_imagingutility_ubuntu.json
IMG_TYPE := Server
VERSION := 20.10
MACHINE := arm64

IMG_INFO := $(shell curl -LSs $(INFO_URL) | jq -r "[.os_list[] | select(.name | test(\"$(IMG_TYPE) $(VERSION)\")) | select(.url | test(\"$(MACHINE)\"))][0]")
IMG_URL := $(shell jq -r '.url' <<< '$(IMG_INFO)')

DL_SIZE := $(shell jq -r '.image_download_size' <<< '$(IMG_INFO)')
FILESIZE := $(shell jq -r '.extract_size' <<< '$(IMG_INFO)')
CHECKSUM := $(shell jq -r '.extract_sha256' <<< '$(IMG_INFO)')
ARCHIVE := $(addprefix images/,$(notdir $(IMG_URL)))
FILENAME := $(basename $(ARCHIVE:.zip=.img.zip))

download: $(ARCHIVE)
extract: $(FILENAME)
	@echo "Validating Image"
	@echo -e "  filename: $$(tput setaf 6)$(FILENAME)$$(tput sgr0)"
	@echo -e "  checksum: $$(tput setaf 2)$(CHECKSUM)$$(tput sgr0)\n"
	@pv -s $(FILESIZE) $(<) | shasum -a 256 -c <(echo $(CHECKSUM)\ \ \-)
	@$(RM) $(ARCHIVE)
clean:
	$(RM) -rf images/*

$(FILENAME): $(ARCHIVE)
$(ARCHIVE):
	@echo "Downloading image to $$(tput setaf 6)$(FILENAME)$$(tput sgr0)"
	@echo "$$(tput setaf 2)$(IMG_URL)$$(tput sgr0)"
	@curl -o $(@) -LSO $(IMG_URL)
%.img: %.zip
	@echo 'Unpacking archive'
	@unzip -d images $?
%.img: %.img.xz
	@echo 'Unpacking archive'
	@pv -s $(DL_SIZE) $< | pixz -d -t 2>/dev/null > $@

.PHONY: build clean download
