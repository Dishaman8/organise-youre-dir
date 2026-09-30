# Organise your directory

`orgnise-dir.sh` sorts files in one directory into folders by file extension. It checks only files directly in the target directory; it does not scan subfolders or inspect file contents.

## Run it

Make the script executable once, then run it from the directory you want to organize:

```bash
chmod +x /path/to/orgnise-dir.sh
cd ~/Downloads
/path/to/orgnise-dir.sh
```

You can also run it against a directory without changing directories:

```bash
/path/to/orgnise-dir.sh ~/Downloads
```

With no argument, it organizes the current working directory. `--help` prints usage. The script itself and `README.md` are left where they are. Existing destination files are never overwritten; a numbered suffix is added to a duplicate filename. Running it again does not re-sort files already inside category folders.

## Folders and file types

The script creates these folders in the target directory:

| Folder | Examples of extensions |
| --- | --- |
| `Photos` | jpg, jpeg, png, gif, webp, heic, svg, raw |
| `Videos` | mp4, mkv, mov, avi, webm, mpeg |
| `Text Files` | txt, md, csv, jsonl, html, py, sh, source code and configuration files |
| `App Image Files` | appimage, exe, msi, deb, rpm, dmg, apk, iso, img |
| `DKBG Files` | dkbg, log, debug, stackdump, dmp, dump, trace, core |
| `PDF Files` | pdf |
| `Microsoft Files` | doc/docx, xls/xlsx, ppt/pptx, and related Office formats |
| `Token Files` | token(s), credential(s), secret(s), env (including `.env`), pem, key, p12, pfx |
| `Others` | Files whose extensions are not in the lists above, including files without an extension |

“DKBG” is treated as debug/log output. The token category is based on filenames' extensions only; the script does not read or validate credentials. These folders can contain sensitive files, so choose the target directory carefully.

## Output

The script prints the resolved target path, the number of files it found, how many it moved successfully, and a per-folder count with the filenames moved during this run. It exits with an error if it cannot access the target, create a category folder, or move one or more files.

## Requirements and notes

- Bash 4+ (for case-insensitive extension matching and associative arrays), plus `mkdir` and `mv`.
- Matching is case-insensitive and extension-based. Unknown or misleading extensions go to `Others` or may be classified incorrectly.
- Category counts include files already present in each category folder; the printed filenames list only files moved in the current run.
- Hidden files are included. Directories and their contents are not moved.
