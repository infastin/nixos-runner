#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options]

Parse AWS credentials file and extract credentials

Options:
  -i              Print only access key id
  -s              Print only secret access key
  -p <profile>    Profile for which to extract credentials (default: "[default]")
  -f <file>       Path to the file with credentials (default: ~/.aws/credentials)
  -h              Display the help message for this script
EOF
}

parse() {
  local file="$1"
  local profile="$2"

  local section=""

  while IFS='=' read key value; do
    if [[ "$key" == \[*] ]]; then
      section="$key"
    elif [[ -n "$value" ]] && [[ "$section" == "$profile" ]]; then
      case "$key" in
        "aws_access_key_id")
          ACCESS_KEY_ID="$value"
          ;;
        "aws_secret_access_key")
          SECRET_ACCESS_KEY="$value"
          ;;
      esac
    fi
  done < "$file"
}

ONLY_ACCESS_KEY_ID=false
ONLY_SECRET_ACCESS_KEY=false
PROFILE=[default]
CREDS_FILE=~/.aws/credentials

while getopts "isp:f:h" arg; do
  case $arg in
    i)
      ONLY_ACCESS_KEY_ID=true
      ;;
    s)
      ONLY_SECRET_ACCESS_KEY=true
      ;;
    p)
      PROFILE="$OPTARG"
      ;;
    f)
      CREDS_FILE="$OPTARG"
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

if [ $# -ne 0 ]; then
  echo "$0: too many arguments"
  usage
  exit 1
fi

parse "$CREDS_FILE" "$PROFILE"

if ! [ -v ACCESS_KEY_ID ] && [ -v SECRET_ACCESS_KEY ]; then
  echo "No credentials found"
  exit 1
fi

if $ONLY_ACCESS_KEY_ID; then
  echo "$ACCESS_KEY_ID"
elif $ONLY_SECRET_ACCESS_KEY; then
  echo "$SECRET_ACCESS_KEY"
else
  echo "$ACCESS_KEY_ID $SECRET_ACCESS_KEY"
fi
