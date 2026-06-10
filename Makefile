# Usage:
#   make                       # pick a project with fzf, run the workflow
#   make <target>              # pick a project with fzf, run one step (e.g. make cut)
#   make PROJECT=foo           # no fzf; bare name expands to projects/foo
#   make <target> PROJECT=foo  # same, a single step on projects/foo
#   make PROJECT=projects/foo  # explicit path also works
#   make new                   # pick a NAS event folder, create the project, run everything
#   make init [name]           # pick a NAS event folder; create the project only (no run)
#   make dispatch              # sort a 動画回収 bucket into per-event folders
#   make mount                 # ensure the NAS share is mounted

# Expand a bare PROJECT=foo into projects/foo (leave explicit paths untouched).
# `override` is needed so a command-line PROJECT=foo is still expanded.
ifneq ($(origin PROJECT), undefined)
  ifeq ($(findstring /,$(PROJECT)),)
    override PROJECT := projects/$(PROJECT)
  endif
endif

# Targets that pick/derive their own project (so they need no PROJECT here).
NO_PROJECT := mount dispatch patch-youtube-upload init new queue status enqueue
# Goals that need a project (no goals => default `all`).
GOALS := $(if $(MAKECMDGOALS),$(MAKECMDGOALS),all)
NEED_PROJECT := $(filter-out $(NO_PROJECT),$(GOALS))

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

# `make` runs everything except the YouTube upload (push, then mark the NAS
# folder edited); run `make publish <name>` separately to publish.
all: mount pull cut title combine check push edited

mount:
	bash scripts/mount_nas.sh

dispatch: mount
	bash scripts/dispatch.sh $(DUMP)

cut:
	bash scripts/cut_clips.sh $(PROJECT)

title:
	bash scripts/add_title_and_fade.sh $(PROJECT)

combine:
	bash scripts/concat_clips.sh $(PROJECT)

check:
	bash scripts/check_final.sh $(PROJECT)

check-raw:
	ffprobe -v error -show_format -show_streams $(PROJECT)/output/final.mp4

publish:
	bash scripts/upload_to_youtube.sh $(PROJECT)

init:
	bash scripts/init_project.sh $(PROJECT)

# Pick a NAS event folder, create the project, then run the full workflow on it.
new:
	@dir=$$(bash scripts/init_project.sh) && $(MAKE) PROJECT="$$dir" all

pull: mount
	bash scripts/pull_input_clips.sh $(PROJECT)

push:
	bash scripts/push_output.sh $(PROJECT)

patch-youtube-upload:
	cd submodules/youtube-upload && git apply ../../patches/youtube-upload.patch

clean:
	rm -rf $(PROJECT)/output

# Mark a project's NAS folder as edited (drop the 【未編集】 prefix, fix config).
edited:
	bash scripts/mark_edited.sh $(PROJECT)

# Queue a project for the nightly run. With PROJECT=foo, queue that existing
# project; with no argument, pick a NAS event folder, init it, then queue it.
enqueue:
	@if [ -n "$(PROJECT)" ]; then \
	  echo "$(PROJECT)" >> queue.txt && echo "queued: $(PROJECT)"; \
	else \
	  dir=$$(bash scripts/init_project.sh) && echo "$$dir" >> queue.txt && echo "queued: $$dir"; \
	fi

# Run all queued projects one at a time at low priority (manual nightly kick).
queue:
	bash scripts/run_queue.sh

# Show each project's processing status (built / pushed / published / queued).
status:
	bash scripts/status.sh

.PHONY: all cut title combine check check-raw publish init new pull push patch-youtube-upload clean edited mount dispatch enqueue queue status
