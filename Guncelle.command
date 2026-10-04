#!/bin/bash
# En son sürümü indirir ve Xcode projesini yeniden açar.
# Xcode'un kendiliğinden yaptığı küçük değişiklikler (ör. .xcstrings) silinmez, `git stash` ile kenara alınır.
set -euo pipefail
cd "$(dirname "$0")"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Yerel değişiklikler kenara alınıyor (git stash)..."
  git stash push --quiet --message "Guncelle.command $(date '+%Y-%m-%d %H:%M')"
fi

echo "Yeni sürüm indiriliyor..."
# Yayınlanan sürüm her zaman ana dalda (main)
git fetch --quiet origin main
git checkout --quiet main
git pull --ff-only origin main

./ProjeyiAc.command
