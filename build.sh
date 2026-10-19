#!/bin/bash
set -e

FLUTTER_VERSION="3.44.0"
CACHE_DIR="/vercel/.cache"
FLUTTER_DIR="$CACHE_DIR/flutter"
PUB_CACHE_DIR="node_modules/.pub-cache"

export PUB_CACHE="$(pwd)/$PUB_CACHE_DIR"

if [ ! -f "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Cloning Flutter SDK $FLUTTER_VERSION..."
  mkdir -p "$CACHE_DIR"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

git config --global --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web --no-analytics

APP_VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1)"
DART_DEFINES="--dart-define=APP_VERSION=$APP_VERSION"
[ -n "$STRAVA_CLIENT_ID" ] && DART_DEFINES="$DART_DEFINES --dart-define=STRAVA_CLIENT_ID=$STRAVA_CLIENT_ID"
[ -n "$STRAVA_CLIENT_SECRET" ] && DART_DEFINES="$DART_DEFINES --dart-define=STRAVA_CLIENT_SECRET=$STRAVA_CLIENT_SECRET"
[ -n "$STRAVA_REDIRECT_URI" ] && DART_DEFINES="$DART_DEFINES --dart-define=STRAVA_REDIRECT_URI=$STRAVA_REDIRECT_URI"
[ -n "$STRAVA_ACCESS_TOKEN" ] && DART_DEFINES="$DART_DEFINES --dart-define=STRAVA_ACCESS_TOKEN=$STRAVA_ACCESS_TOKEN"
[ -n "$STRAVA_REFRESH_TOKEN" ] && DART_DEFINES="$DART_DEFINES --dart-define=STRAVA_REFRESH_TOKEN=$STRAVA_REFRESH_TOKEN"

flutter build web --release $DART_DEFINES
