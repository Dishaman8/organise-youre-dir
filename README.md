# Organise your directory

`orgnise-dir.sh` sorts files in one directory into category folders. It checks only files directly in the target directory; it does not scan arbitrary subfolders or inspect file contents.

## Run it

Make the script executable once, then run it from the directory to organize:

```bash
chmod +x /path/to/orgnise-dir.sh
cd ~/Downloads
/path/to/orgnise-dir.sh
```

Or pass a directory explicitly:

```bash
/path/to/orgnise-dir.sh ~/Downloads
```

With no argument, the current working directory is used. `--help` prints usage. The script itself and `README.md` are left in place. Duplicate destination names receive a numbered suffix instead of being overwritten.

## Folders and file types

| Folder | Examples |
| --- | --- |
| `Photos` | jpg, jpeg, png, gif, webp, heic, svg, raw |
| `Videos` | mp4, mkv, mov, avi, webm, mpeg |
| `Text Files` | txt, md, csv, jsonl, html, py, sh, source code and configuration files |
| `App Image Files` | appimage, exe, msi, deb, rpm, dmg, apk, iso, img |
| `DKBG Files` | dkbg, log, debug, stackdump, dmp, dump, trace, core |
| `PDF Files` | pdf |
| `Microsoft Files` | doc/docx, xls/xlsx, ppt/pptx, and related Office formats |
| `Token Files` | token(s), credential(s), secret(s), env, pem, key, p12, pfx |
| `Others` | Unmatched extensions and files without extensions |

## Photo and video naming

- WhatsApp-style photos such as `IMG-20240921-WA0001.jpg` and `WhatsApp Image ...jpg` go into `Photos/WhatsApp Photos` and are renamed `Photo 001.jpg`, `Photo 002.jpg`, and so on. The next number is chosen after any numbered photos already there. Other photos keep their original names.
- TV episodes recognized by `S01E02` or `1x02` naming go into `Videos/TV Shows/<Show>/Season 01/` and are named `<Show> - S01E02.ext`.
- Videos with a year in the name, such as `The.Movie.2024.1080p.WEB-DL.x264.mkv`, go into `Videos/Movies/The Movie (2024)/` and are named `The Movie (2024).mkv`.
- When a recognized quality or release tag appears without a year, the script strips the tag and uses the remaining title to make a movie folder. Recognized tags include resolution, WEB-DL/WEBRip, Blu-ray, common codecs, HDR, and release markers.
- Dotted or underscored video names are treated as movie titles and normalized to spaces even if no year or release tag is present.
- Other videos keep their original names in `Videos`.

The script renames and moves media files; it does not delete file contents. Movie/show recognition relies on common filename patterns. Unusual naming may leave a video in the general `Videos` folder or produce an imperfect title. Review the output before relying on automated grouping for a large collection.

## Output

The script prints the target path, found and organized totals, then a compact category table showing files in each folder and files moved in this run. It uses color in an interactive terminal and plain text when output is redirected. It then lists the moved filenames for each category.

## Requirements and notes

- Bash 4+ (case-insensitive matching, associative arrays, and recursive glob counting), plus `mkdir` and `mv`.
- Matching is case-insensitive and extension-based. A misleading extension may classify a file incorrectly.
- Hidden files are included. Nested directories are not scanned as input, but category totals include files inside movie and TV subfolders.
- `DKBG` is treated as debug/log output, and `.dkbg` is included explicitly.
- Token/credential files are identified by extension only. The script never reads their contents; choose the target directory carefully.
