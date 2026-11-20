#!/usr/bin/env bash
set -euo pipefail
# Check the listening socket without opening a login connection or adding auth logs.
ss -H -ltn | awk '$4 ~ /:22$/ { found=1 } END { exit !found }'
