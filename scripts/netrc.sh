#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options] <host>

Parse netrc file and extract login and password for the given host

Options:
  -l           Print only login
  -p           Print only password
  -f <file>    Path to netrc file (default: ~/.netrc)
  -h           Display the help message for this script

Parameters:
  host    Target host
EOF
}

parse() {
  local file="$1"
  local host="$2"

  local default=false
  local found=false
  local prev=""

  while read line; do
    for token in $line; do
      case $token in
        default)
          if ! $found; then
            default=true
          fi
          ;;
        machine)
          if $found; then
            break 2
          fi
          default=false
          prev="$token"
          ;;
        login | password)
          prev="$token"
          ;;
        *)
          case $prev in
            machine)
              if [[ "$token" == "$host" ]]; then
                found=true
              fi
              ;;
            login)
              if $found || $default; then
                LOGIN="$token"
              fi
              ;;
            password)
              if $found || $default; then
                PASSWORD="$token"
              fi
              ;;
          esac
      esac
    done
  done < "$file"
}

ONLY_LOGIN=false
ONLY_PASSWORD=false
NETRC_FILE=~/.netrc

while getopts "lpf:h" arg; do
  case $arg in
    l)
      ONLY_LOGIN=true
      ;;
    p)
      ONLY_PASSWORD=true
      ;;
    f)
      NETRC_FILE="$OPTARG"
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

case $# in
  0)
    echo "$0: expected host"
    usage
    exit 1
    ;;
  1)
    ;;
  *)
    echo "$0: too many arguments"
    usage
    exit 1
    ;;
esac

parse "$NETRC_FILE" "$1"

if [ ! -v LOGIN ]; then
  echo "No credentials found"
  exit 1
fi

if $ONLY_LOGIN; then
  echo "$LOGIN"
elif $ONLY_PASSWORD; then
  echo "${PASSWORD:-}"
else
  echo "$LOGIN ${PASSWORD:-}"
fi
