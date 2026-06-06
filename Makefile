# Usage:
#   make                       # pick a project with fzf, run the full workflow
#   make <project-name>        # run the full workflow on projects/<name>, no fzf
#   make <target> <name>       # run a single target on projects/<name>
#   make PROJECT=foo           # same; bare name is expanded to projects/foo
#   make PROJECT=projects/foo  # explicit path also works
#   make init <project-name>   # create a new project
#   make dispatch              # sort a 動画回収 bucket into per-event folders
#   make mount                 # ensure the NAS share is mounted

KNOWN_TARGETS := all cut title combine check check-raw upload init pull push patch-youtube-upload clean mount dispatch

# Any command-line word that is not a known target is treated as the project name,
# so you can write `make foo` or `make cut foo` instead of PROJECT=projects/foo.
ARGS := $(filter-out $(KNOWN_TARGETS),$(MAKECMDGOALS))
REAL_GOALS := $(filter $(KNOWN_TARGETS),$(MAKECMDGOALS))
ifneq ($(strip $(ARGS)),)
  PROJECT := projects/$(word 1,$(ARGS))
  .PHONY: $(ARGS)
  ifeq ($(strip $(REAL_GOALS)),)
    # `make foo` -> run the full workflow on that project.
    $(ARGS): all
	@:
  else
    # `make cut foo` -> the name is just the project; do nothing for it.
    $(ARGS):
	@:
  endif
endif

# Expand a bare PROJECT=foo into projects/foo (leave explicit paths untouched).
# `override` is needed so a command-line PROJECT=foo is still expanded.
ifneq ($(origin PROJECT), undefined)
  ifeq ($(findstring /,$(PROJECT)),)
    override PROJECT := projects/$(PROJECT)
  endif
endif

# Targets that do not operate on a project.
NO_PROJECT := mount dispatch patch-youtube-upload
# Goals that need a project (no goals => default `all`, which needs one).
NEED_PROJECT := $(filter-out $(NO_PROJECT),$(if $(MAKECMDGOALS),$(REAL_GOALS),all))

# Fall back to interactive fzf selection only when a project is needed but unset.
ifeq ($(origin PROJECT), undefined)
  ifneq ($(strip $(NEED_PROJECT)),)
    ifneq ($(findstring p,$(MAKEFLAGS)),p)
      PROJECT := $(shell ls -td projects/*/ | fzf)
      ifeq ($(strip $(PROJECT)),)
        $(error No project selected)
      endif
    endif
  endif
endif

all: mount pull cut title combine check upload push

mount:
	bash scripts/mount_nas.sh

dispatch: mount
	bash scripts/dispatch.sh $(DUMP)

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

pull: mount
	bash scripts/pull_input_clips.sh $(PROJECT)

push:
	bash scripts/push_output.sh $(PROJECT)

patch-youtube-upload:
	cd submodules/youtube-upload && git apply ../../patches/youtube-upload.patch

clean:
	rm -rf $(PROJECT)/output

.PHONY: all cut title combine check check-raw upload init pull push patch-youtube-upload clean mount dispatch
