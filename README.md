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

Or specify the project directory manually:

```bash
make PROJECT=projects/example
```

To create a new project directory under `projects/`:

```bash
make init example
```

Available targets:

- `make cut` – Cut or link clips using `config.sh`
- `make title` – Add title, subtitle, fade-in/out
- `make combine` – Concatenate clips and encode audio
- `make check` – Print info about final.mp4
- `make check-raw` – Run ffprobe and show raw stream info
- `make upload` – Upload final.mp4 to YouTube using youtube-upload
- `make init <name>` – Create initial project structure under `projects/<name>`
- `make pull` - Pull input_clips from NAS
- `make push` - Push final.mp4 and config files to NAS
- `make clean` – Remove output files

## Sample files

### `config.sh`

```bash
#!/bin/bash

TITLE="Sports Day 2024"
SUBTITLE="Elementary School Field Event"
NAS_SOURCE_DIR="/path/to/nas/project_dir"

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
