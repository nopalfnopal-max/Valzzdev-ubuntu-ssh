#!/usr/bin/env bash
set -Eeuo pipefail

line() { printf '%s\n' '------------------------------------------------------------'; }
format_bytes() {
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || printf '%s bytes' "$1"
  else
    printf '%s bytes' "$1"
  fi
}

printf '\nVALZZ / VALZZHOST SERVER STATUS\n'
line
printf 'Hostname : %s\n' "$(hostname 2>/dev/null || echo unknown)"
if [[ -r /etc/os-release ]]; then . /etc/os-release; printf 'OS       : %s\n' "${PRETTY_NAME:-Linux}"; fi
printf 'Uptime   : %s\n' "$(uptime -p 2>/dev/null || echo unknown)"
printf 'Kernel   : %s\n' "$(uname -r)"
printf 'Node.js  : %s\n' "$(node --version 2>/dev/null || echo not-installed)"
printf 'npm      : %s\n' "$(npm --version 2>/dev/null || echo not-installed)"
printf 'PM2      : %s\n' "$(pm2 --version 2>/dev/null || echo not-installed)"
line
printf 'Memory reported by free:\n'
free -h 2>/dev/null || true

# cgroup v2 (commonly used by Railway and modern Docker runtimes).
if [[ -r /sys/fs/cgroup/memory.max ]]; then
  mem_limit="$(cat /sys/fs/cgroup/memory.max)"
  mem_current="$(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo 0)"
  if [[ "$mem_limit" != max && "$mem_limit" =~ ^[0-9]+$ ]]; then
    printf 'Container RAM limit : %s\n' "$(format_bytes "$mem_limit")"
    printf 'Container RAM used  : %s\n' "$(format_bytes "$mem_current")"
  else
    printf 'Container RAM limit : unlimited (cgroup v2)\n'
  fi
elif [[ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
  mem_limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)"
  mem_current="$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo 0)"
  printf 'Container RAM limit : %s\n' "$(format_bytes "$mem_limit")"
  printf 'Container RAM used  : %s\n' "$(format_bytes "$mem_current")"
fi

line
printf 'CPU quota:\n'
if [[ -r /sys/fs/cgroup/cpu.max ]]; then
  read -r quota period < /sys/fs/cgroup/cpu.max
  if [[ "$quota" == max ]]; then
    printf 'Container CPU limit : unlimited (cgroup v2)\n'
  else
    awk -v q="$quota" -v p="$period" 'BEGIN { if (p > 0) printf "Container CPU limit : %.2f vCPU\n", q/p }'
  fi
elif [[ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]]; then
  quota="$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)"
  period="$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)"
  awk -v q="$quota" -v p="$period" 'BEGIN { if (q > 0 && p > 0) printf "Container CPU limit : %.2f vCPU\n", q/p; else print "Container CPU limit : unlimited" }'
fi
line
printf 'Disk usage:\n'
df -h / /data 2>/dev/null | awk '!seen[$0]++'
line
printf 'Persistent directories:\n'
for path in /data /workspace /root/projects /root/.pm2 /data/.npm-global /data/users /data/ssh; do
  if [[ -e "$path" ]]; then printf '  %-20s %s\n' "$path" "$(du -sh "$path" 2>/dev/null | awk '{print $1}' || echo unknown)"; fi
done
line
printf 'SSH listener:\n'
if ss -H -ltn | awk '$4 ~ /:22$/ { found=1 } END { exit !found }'; then
  printf '  SSH port 22: listening\n'
else
  printf '  SSH port 22: not responding\n'
fi
printf '\nUseful commands: pm2 list | pm2 logs | pm2 save | server-status\n\n'
