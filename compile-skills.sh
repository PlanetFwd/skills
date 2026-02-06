#!/bin/bash

set -e
cd "$(dirname "$0")"

for dir in */; do
  [ -d "$dir" ] || continue
  [ "$dir" = ".git/" ] && continue
  name="${dir%/}"
  echo "Creating ${name}.zip from ${dir}"
  zip -qr "${name}.zip" "$name"
done

echo "Done."
