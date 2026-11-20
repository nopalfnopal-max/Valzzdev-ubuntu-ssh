# Environment for interactive SSH login shells.
export DATA_DIR="${DATA_DIR:-/data}"
export WORKSPACE="${WORKSPACE:-/workspace}"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  export PM2_HOME="${PM2_HOME:-${DATA_DIR}/.pm2}"
  export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-${DATA_DIR}/.npm-global}"
else
  export PM2_HOME="${PM2_HOME:-${HOME}/.pm2}"
  export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-${HOME}/.npm-global}"
fi
export PATH="${NPM_CONFIG_PREFIX}/bin:${PATH}"
umask 002
