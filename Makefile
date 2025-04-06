# Usage:
# make OR make PROJECT=projects/example

ifeq ($(origin PROJECT), undefined)
  ifneq ($(filter patch-youtube-upload,$(MAKECMDGOALS)),patch-youtube-upload)
    ifneq ($(findstring p,$(MAKEFLAGS)),p)
      PROJECT := $(shell ls -td projects/*/ | fzf)
      ifeq ($(strip $(PROJECT)),)
        $(error No project selected)
      endif
    endif
  endif
endif

all: cut title combine check

cut:
	bash scripts/cut_clips.sh $(PROJECT)

title:
	bash scripts/add_title_and_fade.sh $(PROJECT)

combine:
	nice -n 19 ionice -c3 bash scripts/concat_clips.sh $(PROJECT)

check:
	bash scripts/check_final.sh $(PROJECT)

check-raw:
	ffprobe -v error -show_format -show_streams $(PROJECT)/output/final.mp4

upload:
	bash scripts/upload_to_youtube.sh $(PROJECT)

init:
	bash scripts/init_project.sh $(PROJECT)

pull:
	bash scripts/pull_input_clips.sh $(PROJECT)

push:
	bash scripts/push_output.sh $(PROJECT)

patch-youtube-upload:
	cd submodules/youtube-upload && git apply ../../patches/youtube-upload.patch

clean:
	rm -rf $(PROJECT)/output

.PHONY: all cut title combine check check-raw upload init pull push patch-youtube-upload clean
