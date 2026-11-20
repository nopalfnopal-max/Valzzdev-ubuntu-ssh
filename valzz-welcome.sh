#!/usr/bin/env bash
# Interactive SSH welcome banner.
[[ $- == *i* ]] || return 0 2>/dev/null || exit 0
[[ -t 1 ]] || return 0 2>/dev/null || exit 0

C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_CYAN=$'\e[38;5;51m'
C_BLUE=$'\e[38;5;33m'
C_GREEN=$'\e[38;5;46m'
C_YELLOW=$'\e[38;5;220m'
C_GREY=$'\e[38;5;245m'
C_WHITE=$'\e[38;5;231m'

_os="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")"
_host="$(hostname 2>/dev/null)"
_user="$(whoami 2>/dev/null)"
_uptime="$(uptime -p 2>/dev/null | sed 's/^up //')"
_mem="$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 " / " $2}')"
_node="$(node -v 2>/dev/null || echo 'n/a')"
_pm2="$(pm2 -v 2>/dev/null || echo 'n/a')"
_disk="$(df -h /data 2>/dev/null | awk 'NR==2 {print $3 " / " $2}')"

printf '\n'
printf '%s\n' "${C_CYAN}${C_BOLD}  ██╗   ██╗  █████╗  ██╗      ███████╗███████╗${C_RESET}"
printf '%s\n' "${C_BLUE}${C_BOLD}  ██║   ██║ ██╔══██╗ ██║      ╚══███╔╝╚══███╔╝${C_RESET}"
printf '%s\n' "${C_BLUE}${C_BOLD}  ╚██╗ ██╔╝ ███████║ ██║        ███╔╝   ███╔╝ ${C_RESET}"
printf '%s\n' "${C_CYAN}${C_BOLD}   ╚████╔╝  ██╔══██║ ██║       ███╔╝   ███╔╝  ${C_RESET}"
printf '%s\n' "${C_CYAN}${C_BOLD}    ╚██╔╝   ██║  ██║ ███████╗ ███████╗███████╗${C_RESET}"
printf '\n'
printf '%s\n' "${C_WHITE}${C_BOLD}          Ubuntu SSH · Persistent Developer Environment${C_RESET}"
printf '%s\n' "${C_YELLOW}          Node.js ${_node} · PM2 ${_pm2}${C_RESET}"
printf '%s\n' "${C_GREY}  ────────────────────────────────────────────────────${C_RESET}"
printf "  ${C_CYAN}User${C_RESET}     │ ${C_WHITE}%s${C_RESET} @ ${C_WHITE}%s${C_RESET}\n" "$_user" "$_host"
printf "  ${C_CYAN}OS${C_RESET}       │ ${C_WHITE}%s${C_RESET}\n" "$_os"
printf "  ${C_CYAN}Uptime${C_RESET}   │ ${C_WHITE}%s${C_RESET}\n" "${_uptime:-just now}"
printf "  ${C_CYAN}Memory${C_RESET}   │ ${C_WHITE}%s${C_RESET}\n" "${_mem:-n/a}"
printf "  ${C_CYAN}Storage${C_RESET}  │ ${C_WHITE}%s${C_RESET}\n" "${_disk:-n/a}"
printf '%s\n' "${C_GREY}  ────────────────────────────────────────────────────${C_RESET}"
printf "  ${C_GREEN}➜${C_RESET} Workspace : ${C_YELLOW}/workspace${C_RESET}\n"
printf "  ${C_GREEN}➜${C_RESET} Projects  : ${C_YELLOW}/root/projects${C_RESET}\n"
printf "  ${C_GREEN}➜${C_RESET} Status    : ${C_YELLOW}server-status${C_RESET}\n"
printf "  ${C_GREEN}➜${C_RESET} PM2       : ${C_YELLOW}pm2 list${C_RESET}  ·  save: ${C_YELLOW}pm2 save${C_RESET}\n"
printf '\n'
