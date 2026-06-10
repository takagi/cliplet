# cliplet

**cliplet** is a personal CLI toolchain for trimming, titling, and joining video clips.

## Usage

Before you start, prepare a project directory under `projects/` like this:

```
projects/example/
├── input_clips/        # Place your original video clips here
└── config.sh           # Project settings (auto-filled by `make init` / `make pull`)
```

Then run the workflow (everything except the YouTube upload) with:

```bash
make
```

Review the result, then publish separately with `make publish <name>`.

If `PROJECT` is not specified, you'll be prompted to select one from the `projects/` directory using `fzf`.

Or pick a project directly without the `fzf` prompt with `PROJECT=` (a bare name
is expanded to `projects/<name>`):

```bash
make PROJECT=example          # full workflow on projects/example
make cut PROJECT=example      # a single target on projects/example
make PROJECT=projects/example # explicit path also works
```

To make a video from scratch, pick a NAS event folder with `make new` — it
creates the project (named after the event) and runs the whole workflow:

```bash
make new                   # pick an event folder, then pull → … → push (upload separately)
```

To only create the project without running anything, use `make init` (pass a
name to override the event-derived directory name):

```bash
make init                  # new project named after the chosen event
make init my-project-name  # force the directory name instead
```

Available targets:

- `make new` – Pick a NAS event folder, create the project, and run the workflow (upload separately)
- `make dispatch` – Sort a `動画回収YYYY-MM-DD` bucket into per-event folders (see below)
- `make mount` – Ensure the NAS SMB share is mounted (run automatically by `pull`/`all`)
- `make cut` – Cut or link clips using `config.sh` (skips clips shorter than `MIN_DURATION`)
- `make title` – Add title, subtitle, fade-in/out
- `make combine` – Concatenate clips and encode audio
- `make check` – Print info about final.mp4
- `make check-raw` – Run ffprobe and show raw stream info
- `make publish` – Upload final.mp4 to YouTube using youtube-upload
- `make init [name]` – Pick a NAS event folder and create a project (named after the event, or `<name>` if given)
- `make pull` - Pull input_clips from NAS
- `make push` - Push final.mp4 and config files to NAS
- `make clean` – Remove output files

## Sorting raw footage (`make dispatch`)

Camera dumps land in a flat bucket on the NAS named `動画回収YYYY-MM-DD`.
`make dispatch` turns that bucket into the per-event folders
(`Movies/<year>/YYYY-MM-DD イベント名/input_clips/`) the rest of the workflow
expects, so `make init` can pick the event folder directly as a project's
`NAS_SOURCE_DIR`.

It runs in two phases:

1. **Generate a mapping and thumbnails.** Clips are grouped by capture date
   (file mtime) and a `dispatch/<bucket>.tsv` is written, one row per date with
   count/size/time span. A per-date contact sheet (one representative frame per
   clip) is also written to `dispatch/thumbs/<bucket>/<date>.jpg` so you can see
   what each day is before naming it.

   ```bash
   make dispatch                 # pick a 動画回収* bucket with fzf
   make dispatch DUMP="/path/to/Movies/動画回収2026-01-21"
   ```

2. **Fill in event names and re-run.** Look at the contact sheets, then edit the
   `=> EVENT` column. Dates that
   share the same name merge into one folder (multi-day trips), prefixed with the
   earliest date; blank leaves those clips in place. Re-running shows a dry-run
   and asks for confirmation before moving (`mv`) the clips.

## Sample files

### `config.sh`

Normally you don't write this by hand. `make init` fills in `TITLE` and
`NAS_SOURCE_DIR` from the NAS event folder you pick, and `make pull` fills in
`SUBTITLE` from the clip dates:

```bash
#!/bin/bash

# Auto-filled by 'make init' from the chosen NAS event folder.
# SUBTITLE is filled in by 'make pull' from the clip dates.
TITLE="運動会 2024"                                   # "<event> <year>"
SUBTITLE="2024.05.18 - 2024.05.19"                    # span of clip dates
NAS_SOURCE_DIR="/path/to/nas/Movies/2024/2024-05-18 運動会"

# Optional per-clip exclusion ranges (format: "start-end;start-end"); unused by default.
declare -A EXCLUDES=()
# EXCLUDES["C0010.MP4"]="00:03-00:08;00:15-00:20"
```

To override a value, just edit it after `init`/`pull`. Nothing rewrites
`TITLE` or `NAS_SOURCE_DIR` again, and `make pull` fills in `SUBTITLE` only
when it is still empty. Clips shorter than `MIN_DURATION` seconds (default 10)
are skipped on `make cut`.

## Example output

```bash
$ make
bash scripts/cut_clips.sh projects/example
bash scripts/add_title_and_fade.sh projects/example
Adding title and fade-in to: C0001_part0.mp4
[Title]   [##################################################] 100%
Title and fade-in complete.
Adding fade-out to: C0005_part0.mp4
[Fadeout] [##################################################] 100%
Fade-out complete.
nice -n 19 ionice -c3 bash scripts/concat_clips.sh projects/example
[##################################################] 100%
Concatenation complete.
bash scripts/check_final.sh projects/example
===> Final video info (projects/example/output/final.mp4):

---- Video ----
Codec:  h264
Size:   3840x2160 @ 29.97 fps

---- Audio ----
Codec:    aac
Channels: 2

---- File ----
Duration:  1832.8 sec
Size:      12097.0 MB
Bitrate:   55369.0 kbps
```

## License

This project is licensed under the MIT License.
