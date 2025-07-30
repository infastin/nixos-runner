#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <command> [arguments]

Parse and manipulate semver/chronover

Commands:
  fmt     Format semver/chronover
  bump    Bump one part of semver
  now     Get chronover for the current date
  help    Display the help message for this script
EOF
}

usage_fmt() {
  cat <<EOF
Usage: $0 fmt [options] [format] [version]

Format semver/chronover

Options:
  -h    Display the help message for this command

Parameters:
  version    Version to parse and format (read from stdin if not specified)
  format     Output format (default: %M.%m%P)

Format specifiers:
  %M, %Y    Major version or Year
  %m        Minor version or Month
  %p        Patch
  %P        Patch with dot before specifier value if defined
  %r        Release
  %R        Release with hyphen before specifier value if defined
  %%        Literal %

Examples:
  $0 1.2.3-rc.1                # Outputs 1.2.3
  $0 "%M.%m.%p" 1.2.3-rc.1     # Outputs 1.2.3
  $0 "%M.%m.%p%R" 1.2-3        # Outputs 1.2.3
  $0 "%M.%m%P%R" 1.2.3-rc.1    # Outputs 1.2.3-rc.1
  $0 "%M.%m%p%R" 1.2-rc.1      # Outputs 1.2-rc.1
  $0 "%M.%m%P%R" 1.2           # Outputs 1.2
EOF
}

usage_bump() {
  cat <<EOF
Usage: $0 bump [options] [version]

Bump one part of semver zeroing or removing subsequent parts
Bumps minor version by default

Options:
  -j    Bump major by one
  -m    Bump minor by one
  -p    Bump patch by one
  -r    Keep release in the output
  -h    Display the help message for this command

Parameters:
  version    Version to parse and bump (read from stdin if not specified)
EOF
}

usage_now() {
  cat <<EOF
Usage: $0 now [options]

Get chronover for the current date

Options:
  -h    Display the help message for this command
EOF
}

parse_version() {
  local version="$1"

  if [[ ! "$version" =~ ^v?[0-9]+\.[0-9]+(\.[0-9]+)?(\-[a-z0-9A-Z.-]+)?$ ]]; then
    echo "Invalid version: $version" >&2
    exit 1
  fi

  if [[ "$version" == v* ]]; then
    HAS_V=true
  else
    HAS_V=false
  fi

  IFS='-' read -r version RELEASE <<< "${version#v}"
  IFS='.' read MAJOR MINOR PATCH <<< "${version}"
}

fmt_version() {
  while getopts "h" arg; do
    case $arg in
      h)
        usage_fmt
        exit 0
        ;;
      *)
        usage_fmt
        exit 1
        ;;
    esac
  done

  shift $((OPTIND - 1))

  local version=""
  local format="%M.%m%P"

  case $# in
    0)
      version=$(</dev/stdin)
      ;;
    1)
      format="$1"
      version=$(</dev/stdin)
      ;;
    2)
      format="$1"
      version="$2"
      ;;
    *)
      echo "$0: too many arguments"
      usage_fmt
      exit 1
      ;;
  esac

  parse_version "$version"

  local result=""

  for (( i=0; i<${#format}; i++ )); do
    if [ "${format:i:1}" == "%" ] && [ $((i+1)) -lt ${#format} ]; then
      case "${format:i+1:1}" in
        M | Y) # Major version / Year
          result+="$MAJOR"
          ;;
        m) # Minor version / Month
          result+="$MINOR"
          ;;
        p) # Patch
          result+="$PATCH"
          ;;
        P) # Patch with dot
          if [[ -n "$PATCH" ]]; then
            result+=".$PATCH"
          fi
          ;;
        r) # Release
          result+="$RELEASE"
          ;;
        R) # Release with hyphen
          if [[ -n "$RELEASE" ]]; then
            result+="-$RELEASE"
          fi
          ;;
        %) # Literal %
          result+="%"
          ;;
        *)
          result+="%${format:i+1:1}"
          ;;
        esac
        i=$((i+1))
    else
      result+="${format:i:1}"
    fi
  done

  echo "$result"
}

bump_version() {
  local bump="m"
  local keep_release=false

  while getopts "jmprh" arg; do
    case $arg in
      j | m | p)
        bump="$arg"
        ;;
      r)
        keep_release=true
        ;;
      h)
        usage_bump
        exit 0
        ;;
      *)
        usage_bump
        exit 1
        ;;
    esac
  done

  shift $((OPTIND - 1))

  local version=""

  case $# in
    0)
      version=$(</dev/stdin)
      ;;
    1)
      version="$1"
      ;;
    *)
      echo "$0: too many arguments"
      usage_bump
      exit 1
      ;;
  esac

  parse_version "$version"

  case $bump in
    j)
      MAJOR=$((MAJOR+1))
      MINOR=0
      if [ -n "$PATCH" ]; then
        PATCH=0
      fi
      ;;
    m)
      MINOR=$((MINOR+1))
      if [ -n "$PATCH" ]; then
        PATCH=0
      fi
      ;;
    p)
      if [ -z "$PATCH" ]; then
        PATCH=0
      fi
      PATCH=$((PATCH+1))
      ;;
  esac

  local result="$MAJOR.$MINOR"
  if [ -n "$PATCH" ]; then
    result+=".$PATCH"
  fi
  if $keep_release && [ -n "$RELEASE" ]; then
    result+="-$RELEASE"
  fi

  if $HAS_V; then
    echo "v$result"
  else
    echo "$result"
  fi
}

now() {
  while getopts "h" arg; do
    case $arg in
      h)
        usage_now
        exit 0
        ;;
      *)
        usage_now
        exit 1
        ;;
    esac
  done

  shift $((OPTIND - 1))

  if [ $# -ne 0 ]; then
    echo "$0: too many arguments"
    usage_now
    exit 1
  fi

  date +'%Y.%m'
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

case "$1" in
  fmt)
    shift 1
    fmt_version "$@"
    ;;
  bump)
    shift 1
    bump_version "$@"
    ;;
  now)
    shift 1
    now "$@"
    ;;
  help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac
