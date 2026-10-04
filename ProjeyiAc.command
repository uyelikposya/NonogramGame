#!/bin/bash
# Xcode projesini üretip açar. Homebrew gerektirmez; Intel ve Apple Silicon Mac'lerde çalışır.
# Finder'da çift tıklayarak ya da Terminal'de ./ProjeyiAc.command ile çalıştır.
set -euo pipefail
cd "$(dirname "$0")"

XCODEGEN=.tools/xcodegen/bin/xcodegen
if [ ! -x "$XCODEGEN" ]; then
  echo "XcodeGen indiriliyor (yalnızca ilk seferde)..."
  mkdir -p .tools
  curl -fsSL -o .tools/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
  unzip -qo .tools/xcodegen.zip -d .tools
  rm .tools/xcodegen.zip
fi

echo "Xcode projesi üretiliyor..."
"$XCODEGEN" generate --quiet
# CI'da yalnızca proje üretilir, Xcode açılmaz
if [ -z "${CI:-}" ]; then
  open Catgrid.xcodeproj
  echo "Hazır! Xcode'da iPhone 15 simülatörünü seçip ⌘R ile çalıştır."
fi
