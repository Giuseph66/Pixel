#!/bin/sh
printf '\033c\033]0;%s\a' PIXEL
base_path="$(dirname "$(realpath "$0")")"
"$base_path/PIXEL.x86_64" "$@"
