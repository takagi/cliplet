# cliplet

**cliplet** is a personal CLI toolchain for trimming, titling, and joining video clips.

## Usage

Before you start, prepare a project directory under `projects/` like this:

```
projects/example/
├── input_clips/        # Place your original video clips here
└── config.sh           # Project settings (title, subtitle, NAS path, excludes)
```

Then run the full workflow with:

```bash
make
```

If `PROJECT` is not specified, you'll be prompted to select one from the `projects/` directory using `fzf`.

Or run a project directly without the `fzf` prompt (a bare name is expanded to
`projects/<name>`):

```bash
make example                 # full workflow on projects/example
make cut example             # a single target on projects/example
make PROJECT=example         # same; bare name is expanded to projects/example
make PROJECT=projects/example # explicit path also works
```

To create a new project directory under `projects/`:

```bash
make init example
```

Available targets:

- `make dispatch` – Sort a `動画回収YYYY-MM-DD` bucket into per-event folders (see below)
- `make mount` – Ensure the NAS SMB share is mounted (run automatically by `pull`/`all`)
- `make cut` – Cut or link clips using `config.sh` (skips clips shorter than `MIN_DURATION`)
- `make title` – Add title, subtitle, fade-in/out
- `make combine` – Concatenate clips and encode audio
- `make check` – Print info about final.mp4
- `make check-raw` – Run ffprobe and show raw stream info
- `make upload` – Upload final.mp4 to YouTube using youtube-upload
- `make init <name>` – Create initial project structure under `projects/<name>`
- `make pull` - Pull input_clips from NAS
- `make push` - Push final.mp4 and config files to NAS
- `make clean` – Remove output files

## Sorting raw footage (`make dispatch`)

Camera dumps land in a flat bucket on the NAS named `動画回収YYYY-MM-DD`.
`make dispatch` turns that bucket into the per-event folders
(`Movies/<year>/YYYY-MM-DD イベント名/input_clips/`) the rest of the workflow
expects, so the event folder can be used directly as a project's `NAS_SOURCE_DIR`.

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

```bash
#!/bin/bash

TITLE="Sports Day 2024"
SUBTITLE="Elementary School Field Event"
NAS_SOURCE_DIR="/path/to/nas/project_dir"

# Clips shorter than this many seconds are skipped on `make cut` (0 disables).
MIN_DURATION=10

declare -A EXCLUDES=()
EXCLUDES["C0010.MP4"]="00:03-00:08;00:15-00:20"
EXCLUDES["C0011.MP4"]="00:00-00:02"
```

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
