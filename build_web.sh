#!/bin/bash
set -e

FLUTTER_HOME="$HOME/flutter"

# تثبيت Flutter إذا لم يكن موجوداً
if [ ! -d "$FLUTTER_HOME" ]; then
  echo ">>> Installing Flutter..."
  git clone https://github.com/flutter/flutter.git \
    --depth 1 -b stable "$FLUTTER_HOME"
fi

export PATH="$PATH:$FLUTTER_HOME/bin"

echo ">>> Flutter version:"
flutter --version

flutter config --enable-web
flutter pub get
flutter build web --release --no-tree-shake-icons

echo ">>> Build complete: build/web"
