#!/usr/bin/env bash
# orchestrate installer for macOS (the macOS side of install.ps1). It lives in the release repository; the README's
# one line runs it:
#
#   curl -fsSL https://raw.githubusercontent.com/choohui/forme/main/install.sh | bash
#
# It reads latest.json of the newest release, downloads that zip, checks its SHA-256 against latest.json, unpacks it
# into ~/Library/Application Support/orchestrate and runs its setup.sh. A folder that already holds an install is
# updated with its own update.sh (data stays). Nothing needs administrator rights.
#
# With arguments: curl -fsSL .../install.sh | bash -s -- --dir ~/orchestrate
#   --dir <folder>      where to install
#   --source <where>    an https address or a local folder that holds latest.json and the zip (default: the newest release)
#   --no-setup          unpack only; run setup.sh yourself
#   anything else       handed to setup.sh / update.sh (e.g. --yes)
set -u

main() {
  local dir="$HOME/Library/Application Support/orchestrate"
  local source='https://github.com/choohui/forme/releases/latest/download'
  local no_setup=0
  local setup_args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) dir="$2"; shift ;;
      --source) source="$2"; shift ;;
      --no-setup) no_setup=1 ;;
      *) setup_args+=("$1") ;;
    esac
    shift
  done
  fail() { echo; echo "orchestrate installer stopped: $1" >&2; exit 1; }

  [ "$(uname -s)" = Darwin ] || fail 'this installer is for macOS (on Windows use install.ps1).'
  local mac
  mac="$(sw_vers -productVersion)"
  [ "${mac%%.*}" -ge 13 ] 2> /dev/null || fail "macOS 13 (Ventura) or later is needed (this is $mac)."

  local remote=0
  case "$source" in
    https://*|http://127.0.0.1*|http://localhost*) remote=1 ;;
    *://*) fail "--source must be an https address or a local folder: $source" ;;
  esac
  source="${source%/}"

  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/orchestrate-install.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
  fetch() { # name
    if [ "$remote" = 1 ]; then curl -fsSL --retry 3 -o "$work/$1" "$source/$1" || fail "could not download $1"
    else cp -f "$source/$1" "$work/$1" || fail "no $1 in $source"; fi
  }
  field() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$2" | head -n 1; }

  # --- 1 which release -----------------------------------------------------------------------------------------------
  echo "orchestrate installer - from $source"
  fetch latest.json
  local file sha version
  file="$(field file "$work/latest.json")"
  sha="$(field sha256 "$work/latest.json" | tr '[:upper:]' '[:lower:]')"
  version="$(field version "$work/latest.json")"
  [[ "$file" =~ ^orchestrate-[A-Za-z0-9._+-]+\.zip$ ]] || fail "latest.json names an unexpected file: $file"
  [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || fail 'latest.json has no SHA-256.'

  local installed=''
  if [ -f "$dir/release.json" ]; then installed="$(field version "$dir/release.json")"; fi
  if [ -n "$installed" ] && [ "$installed" = "$version" ]; then
    echo "orchestrate $version is already installed in $dir."
    echo "Start it with: bash \"$dir/scripts/start.sh\""
    return 0
  fi
  if [ -z "$installed" ] && [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2> /dev/null)" ]; then
    fail "$dir is not empty and is not an orchestrate install. Choose another folder with --dir."
  fi

  # --- 2 download and check ------------------------------------------------------------------------------------------
  echo "downloading $file"
  fetch "$file"
  [ "$(shasum -a 256 "$work/$file" | cut -d ' ' -f 1)" = "$sha" ] || fail "the SHA-256 of $file differs from latest.json: nothing was installed."
  echo 'sha256 ok'
  printf '%s  %s\n' "$sha" "$file" > "$work/$file.sha256"

  # --- 3 an existing install: its own update.sh (the data stays) -----------------------------------------------------
  if [ -n "$installed" ]; then
    echo "updating $installed -> $version in $dir"
    [ -f "$dir/update.sh" ] || fail "$dir has no update.sh (an install made before macOS support): unpack the zip over it by hand."
    if [ "$no_setup" = 1 ]; then
      mkdir -p "$dir/data"
      cp -f "$work/$file" "$work/$file.sha256" "$dir/data/"
      echo "the new zip is at $dir/data/$file (--no-setup: update.sh was not run)"
      return 0
    fi
    bash "$dir/update.sh" --zip "$work/$file" ${setup_args[@]+"${setup_args[@]}"} < /dev/tty || fail 'update.sh stopped.'
    return 0
  fi

  # --- 4 a new install -----------------------------------------------------------------------------------------------
  echo "installing orchestrate $version into $dir"
  local unpack="$work/unpack"
  mkdir -p "$unpack"
  unzip -q "$work/$file" -d "$unpack" || fail 'could not unpack the zip.'
  set -- "$unpack"/*/
  if [ $# -ne 1 ] || [ ! -f "$1/app/dist-server/server/hub/main.js" ]; then fail 'the zip is not an orchestrate release.'; fi
  mkdir -p "$dir"
  (shopt -s dotglob && mv "${1%/}"/* "$dir"/) || fail "could not move the files into $dir"
  if [ "$no_setup" = 1 ]; then
    echo "unpacked. Next: bash \"$dir/setup.sh\""
    return 0
  fi
  # setup.sh asks questions: read them from the terminal, not from the pipe this script came through
  bash "$dir/setup.sh" ${setup_args[@]+"${setup_args[@]}"} < /dev/tty || fail "setup.sh stopped. Run it again: bash \"$dir/setup.sh\""
}

main "$@"
