#!/bin/sh
set -eu

usage() {
  echo "Usage:"
  echo "  $0 -h"
  echo
  echo "    Print this message."
  echo
  echo "  $0 [-v] [-n] -l -o output_dir"
  echo
  echo "    Extract language servers from the latest VS Codium and ESLint"
  echo "    extension releases, placing them in output_dir. Requires jq."
  echo "    With -v, display the URLs that will be used."
  echo "    With -n, do not copy bundled dependencies."
  echo
  echo "  $0 [-v] [-n] -c vscodium_url -e eslint_extension_url -o output_dir"
  echo
  echo "    Extract language servers from the given URLs, placing them in"
  echo "    output_dir."
  echo "    With -v, display the URLs that will be used."
  echo "    With -n, do not copy bundled dependencies."
  echo
  echo "    -c and -e take precedence over -l, allowing use of the latest of"
  echo "    either along with an earlier release of the other."
  echo
  echo "    -n is used primarily for preparing for npm package publishing."
  echo "    Bundled dependencies are satisfied with peerDependencies when used"
  echo "    as an npm package."
  echo

  exit "${1:-1}"
}

verbose=0
no_dependencies=0
latest=0
verify_integrity=0
BINDIR=""
VSCODIUM_ARCHIVE_URL=""
ESLINT_ARCHIVE_URL=""

while getopts "vnhlio:c:e:" opt; do
  case "$opt" in
  v) verbose=1 ;;
  n) no_dependencies=1 ;;
  l) latest=1 ;;
  i) verify_integrity=1 ;;
  o) BINDIR="$OPTARG" ;;
  c) VSCODIUM_ARCHIVE_URL="$OPTARG" ;;
  e) ESLINT_ARCHIVE_URL="$OPTARG" ;;
  h) usage 0 ;;
  ?) usage 1 ;;
  esac
done

if [ -z "$BINDIR" ]; then
  echo "-o is required"
  usage 1
fi

mkdir -p "$BINDIR"

if [ $latest -eq 1 ] && [ -z "$VSCODIUM_ARCHIVE_URL" ]; then
  VSCODIUM_ARCHIVE_URL=$(curl -sL https://api.github.com/repos/vscodium/vscodium/releases/latest | jq -r '.assets[].browser_download_url | select(contains("VSCodium-linux-x64") and endswith("gz"))')
fi

if [ $latest -eq 1 ] && [ -z "$ESLINT_ARCHIVE_URL" ]; then
  ESLINT_ARCHIVE_URL=$(curl -sL https://open-vsx.org/api/dbaeumer/vscode-eslint | jq -r '.files.download')
fi

if [ -z "$VSCODIUM_ARCHIVE_URL" ] || [ -z "$ESLINT_ARCHIVE_URL" ]; then
  echo "Without -l, -c and -e are required"
  usage 1
fi

if [ $verbose -eq 1 ]; then
  echo "BINDIR=$BINDIR"
  echo "VSCODIUM_ARCHIVE_URL=$VSCODIUM_ARCHIVE_URL"
  echo "ESLINT_ARCHIVE_URL=$ESLINT_ARCHIVE_URL"
fi

TMPROOT=${TMPDIR:-"/tmp"}
VSCODIUM_DOWNLOAD_DIR=$(mktemp -d "$TMPROOT/vscodium-download.XXXXXX")
VSCODIUM_EXTRACT_DIR=$(mktemp -d "$TMPROOT/vscodium-extract.XXXXXX")

CSS_SERVER_LOCATION="resources/app/extensions/css-language-features/server/dist/node/cssServerMain.js"
HTML_SERVER_LOCATION="resources/app/extensions/html-language-features/server/dist/node/htmlServerMain.js"
JSON_SERVER_LOCATION="resources/app/extensions/json-language-features/server/dist/node/jsonServerMain.js"
MARKDOWN_SERVER_LOCATION="resources/app/extensions/markdown-language-features/dist/serverWorkerMain.js"
TYPESCRIPT_JS_LOCATION="resources/app/extensions/node_modules/typescript/lib/typescript.js"
TYPESCRIPT_PACKAGE_JSON_LOCATION="resources/app/extensions/node_modules/typescript/package.json"
# Give the odddly-packaged Markdown server a less-generic name
MARKDOWN_BIN_NAME="markdownServerMain.js"

curl -sL "$VSCODIUM_ARCHIVE_URL" > "$VSCODIUM_DOWNLOAD_DIR"/vscodium.tar.gz
if [ $verify_integrity -eq 1 ]; then
  curl -sL "$VSCODIUM_ARCHIVE_URL".sha256 > "$VSCODIUM_DOWNLOAD_DIR"/vscodium.tar.gz.sha256
  EXPECTED_VSCODIUM_HASH=$(awk '{print $1}' < "$VSCODIUM_DOWNLOAD_DIR"/vscodium.tar.gz.sha256)
  ACTUAL_VSCODIUM_HASH=$(openssl sha256 -r "$VSCODIUM_DOWNLOAD_DIR"/vscodium.tar.gz | awk '{print $1}')
  if [ $verbose -eq 1 ]; then
    echo "EXPECTED_VSCODIUM_HASH=$EXPECTED_VSCODIUM_HASH"
    echo "ACTUAL_VSCODIUM_HASH=$ACTUAL_VSCODIUM_HASH"
  fi
  if [ "$EXPECTED_VSCODIUM_HASH" != "$ACTUAL_VSCODIUM_HASH" ]; then
    echo "VSCodium archive integrity check failed."
    exit 1
  fi
fi
gzip -dc "$VSCODIUM_DOWNLOAD_DIR"/vscodium.tar.gz | tar -C "$VSCODIUM_EXTRACT_DIR" -xf - ./"$CSS_SERVER_LOCATION" ./"$HTML_SERVER_LOCATION" ./"$JSON_SERVER_LOCATION" ./"$MARKDOWN_SERVER_LOCATION" ./"$TYPESCRIPT_JS_LOCATION" ./"$TYPESCRIPT_PACKAGE_JSON_LOCATION"

install shims/vscode-css-language-server "$BINDIR"
cp "$VSCODIUM_EXTRACT_DIR"/"$CSS_SERVER_LOCATION" "$BINDIR"
install shims/vscode-html-language-server "$BINDIR"
cp "$VSCODIUM_EXTRACT_DIR"/"$HTML_SERVER_LOCATION" "$BINDIR"
install shims/vscode-json-language-server "$BINDIR"
cp "$VSCODIUM_EXTRACT_DIR"/"$JSON_SERVER_LOCATION" "$BINDIR"
install shims/vscode-markdown-language-server "$BINDIR"
cp "$VSCODIUM_EXTRACT_DIR"/"$MARKDOWN_SERVER_LOCATION" "$BINDIR"/"$MARKDOWN_BIN_NAME"

if [ $no_dependencies -eq 0 ]; then
mkdir -p "$BINDIR"/node_modules/typescript/lib
cp "$VSCODIUM_EXTRACT_DIR"/"$TYPESCRIPT_JS_LOCATION" "$BINDIR"/node_modules/typescript/lib
cp "$VSCODIUM_EXTRACT_DIR"/"$TYPESCRIPT_PACKAGE_JSON_LOCATION" "$BINDIR"/node_modules/typescript
fi

rm -rf "$VSCODIUM_DOWNLOAD_DIR"
rm -rf "$VSCODIUM_EXTRACT_DIR"

ESLINT_DOWNLOAD_DIR=$(mktemp -d "$TMPROOT/eslint-extension-download.XXXXXX")
ESLINT_EXTRACT_DIR=$(mktemp -d "$TMPROOT/eslint-extension-extract.XXXXXX")

ESLINT_SERVER_LOCATION="extension/server/out/eslintServer.js"

curl -sL "$ESLINT_ARCHIVE_URL" >"$ESLINT_DOWNLOAD_DIR"/eslint-extension.zip
unzip -qq "$ESLINT_DOWNLOAD_DIR"/eslint-extension.zip -d "$ESLINT_EXTRACT_DIR"

install shims/vscode-eslint-language-server "$BINDIR"
cp "$ESLINT_EXTRACT_DIR"/"$ESLINT_SERVER_LOCATION" "$BINDIR"

rm -rf "$ESLINT_DOWNLOAD_DIR"
rm -rf "$ESLINT_EXTRACT_DIR"
