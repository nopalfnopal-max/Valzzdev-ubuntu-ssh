#!/usr/bin/env bash
# Runtime initialization for the persistent Ubuntu SSH container.
set -Eeuo pipefail
umask 077

log() { printf '[ValzzHost] %s\n' "$*"; }
die() { printf '[ValzzHost] ERROR: %s\n' "$*" >&2; exit 1; }

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    0|false|no|off) return 1 ;;
    *) return 2 ;;
  esac
}

require_single_line() {
  local name="$1" value="$2"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || die "$name must not contain newline characters."
}

[[ "${EUID}" -eq 0 ]] || die 'This container entrypoint must run as root.'

# Required root credential.
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
[[ -n "$ROOT_PASSWORD" ]] || die 'ROOT_PASSWORD is required. Add it in Railway Variables.'
require_single_line ROOT_PASSWORD "$ROOT_PASSWORD"
printf 'root:%s\n' "$ROOT_PASSWORD" | chpasswd
log 'Root password configured.'

# Runtime options.
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH:-true}"
SSH_ROOT_LOGIN="${SSH_ROOT_LOGIN:-yes}"
SSH_SUDO_NOPASSWD="${SSH_SUDO_NOPASSWD:-false}"
DATA_DIR="${DATA_DIR:-/data}"
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH,,}"
SSH_ROOT_LOGIN="${SSH_ROOT_LOGIN,,}"
SSH_SUDO_NOPASSWD="${SSH_SUDO_NOPASSWD,,}"

is_true "$SSH_PASSWORD_AUTH" || [[ "${SSH_PASSWORD_AUTH,,}" =~ ^(0|false|no|off)$ ]] || die 'SSH_PASSWORD_AUTH must be true or false.'
case "${SSH_ROOT_LOGIN,,}" in
  yes|no|prohibit-password) ;;
  *) die 'SSH_ROOT_LOGIN must be yes, no, or prohibit-password.' ;;
esac
is_true "$SSH_SUDO_NOPASSWD" || [[ "${SSH_SUDO_NOPASSWD,,}" =~ ^(0|false|no|off)$ ]] || die 'SSH_SUDO_NOPASSWD must be true or false.'
# OpenSSH accepts yes/no (not true/false/1/0) for boolean directives.
if is_true "$SSH_PASSWORD_AUTH"; then SSH_PASSWORD_AUTH=yes; else SSH_PASSWORD_AUTH=no; fi
if is_true "$SSH_SUDO_NOPASSWD"; then SSH_SUDO_NOPASSWD=true; else SSH_SUDO_NOPASSWD=false; fi
[[ "$DATA_DIR" = /* && "$DATA_DIR" != "/" ]] || die 'DATA_DIR must be an absolute path other than /. '

# Optional custom hostname. Use a namespaced variable because HOSTNAME is
# commonly injected automatically by Docker/container runtimes.
VALZZ_HOSTNAME="${VALZZ_HOSTNAME:-}"
if [[ -n "$VALZZ_HOSTNAME" ]]; then
  require_single_line VALZZ_HOSTNAME "$VALZZ_HOSTNAME"
  [[ "$VALZZ_HOSTNAME" =~ ^([A-Za-z0-9]([A-Za-z0-9.-]{0,61}[A-Za-z0-9])?)$ ]] || die 'VALZZ_HOSTNAME must be a valid hostname (letters, numbers, dots and hyphens).'
  printf '%s\n' "$VALZZ_HOSTNAME" > /etc/hostname
  hostname "$VALZZ_HOSTNAME" 2>/dev/null || true
  log "Custom hostname set to ${VALZZ_HOSTNAME}."
fi

# Optional secondary login. Username validation prevents path/config injection.
SSH_USERNAME="${SSH_USERNAME:-}"
SSH_PASSWORD="${SSH_PASSWORD:-}"
SSH_USER_AUTHORIZED_KEYS="${SSH_USER_AUTHORIZED_KEYS:-}"
AUTHORIZED_KEYS="${AUTHORIZED_KEYS:-}"

if [[ -n "$SSH_USERNAME" || -n "$SSH_PASSWORD" ]]; then
  [[ -n "$SSH_USERNAME" && -n "$SSH_PASSWORD" ]] || die 'Set both SSH_USERNAME and SSH_PASSWORD, or leave both empty.'
  require_single_line SSH_PASSWORD "$SSH_PASSWORD"
  [[ "$SSH_USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die 'SSH_USERNAME must be 1-32 lowercase letters, digits, underscores or hyphens, and start with a letter or underscore.'
  [[ "$SSH_USERNAME" != root && "$SSH_USERNAME" != sshd ]] || die 'SSH_USERNAME is reserved; choose another username.'

  if id "$SSH_USERNAME" >/dev/null 2>&1; then
    log "Updating existing user ${SSH_USERNAME}."
  else
    useradd --create-home --shell /bin/bash "$SSH_USERNAME"
    log "Created user ${SSH_USERNAME}."
  fi
  printf '%s:%s\n' "$SSH_USERNAME" "$SSH_PASSWORD" | chpasswd
  usermod -aG sudo "$SSH_USERNAME"

  if is_true "$SSH_SUDO_NOPASSWD"; then
    printf '%s ALL=(ALL:ALL) NOPASSWD:ALL\n' "$SSH_USERNAME" > "/etc/sudoers.d/${SSH_USERNAME}"
    chmod 0440 "/etc/sudoers.d/${SSH_USERNAME}"
  else
    rm -f "/etc/sudoers.d/${SSH_USERNAME}"
  fi
  log "Secondary user ${SSH_USERNAME} is ready."
fi

# The Railway volume should be mounted at /data. These paths still work in
# local Docker without a volume, but will then be ephemeral on redeploy.
mkdir -p "$DATA_DIR"
chmod 0755 "$DATA_DIR"
if [[ -s "$DATA_DIR/.workspace_gid" ]]; then
  workspace_gid="$(cat "$DATA_DIR/.workspace_gid")"
  [[ "$workspace_gid" =~ ^[0-9]+$ ]] || die 'The persisted workspace group ID is invalid.'
  if getent group workspace >/dev/null 2>&1; then
    current_workspace_gid="$(getent group workspace | cut -d: -f3)"
    if [[ "$current_workspace_gid" != "$workspace_gid" ]]; then
      groupmod --gid "$workspace_gid" workspace
    fi
  else
    getent group "$workspace_gid" >/dev/null 2>&1 && die "Workspace GID ${workspace_gid} is already assigned to another group."
    groupadd --gid "$workspace_gid" workspace
  fi
else
  if ! getent group workspace >/dev/null 2>&1; then
    if getent group 2000 >/dev/null 2>&1; then groupadd workspace; else groupadd --gid 2000 workspace; fi
  fi
  getent group workspace | cut -d: -f3 > "$DATA_DIR/.workspace_gid"
fi

mkdir -p \
  "$DATA_DIR/workspace" \
  "$DATA_DIR/projects" \
  "$DATA_DIR/backups" \
  "$DATA_DIR/.pm2" \
  "$DATA_DIR/.npm-global" \
  "$DATA_DIR/ssh" \
  "$DATA_DIR/users"
chmod 0755 "$DATA_DIR/users"
chmod 0700 "$DATA_DIR/.pm2" "$DATA_DIR/ssh"
chown root:workspace "$DATA_DIR/workspace" "$DATA_DIR/projects"
chmod 2775 "$DATA_DIR/workspace" "$DATA_DIR/projects"

# Keep the optional user's home directory on the persistent volume too.
if [[ -n "$SSH_USERNAME" ]]; then
  old_home="$(getent passwd "$SSH_USERNAME" | cut -d: -f6)"
  user_home="$DATA_DIR/users/$SSH_USERNAME"
  mkdir -p "$user_home"
  if [[ -n "$old_home" && "$old_home" != "$user_home" && -d "$old_home" ]]; then
    cp -a "$old_home/." "$user_home/" 2>/dev/null || true
  fi
  usermod --home "$user_home" "$SSH_USERNAME"
  if [[ ! -e "$user_home/.valzz-home-initialized" ]]; then
    chown -R "$SSH_USERNAME:$SSH_USERNAME" "$user_home"
    touch "$user_home/.valzz-home-initialized"
    chown "$SSH_USERNAME:$SSH_USERNAME" "$user_home/.valzz-home-initialized"
  fi
  chown "$SSH_USERNAME:$SSH_USERNAME" "$user_home"
  chmod 0750 "$user_home"
  usermod -aG workspace "$SSH_USERNAME"
fi

persist_directory() {
  local target="$1" link="$2" current
  mkdir -p "$target"
  if [[ -L "$link" ]]; then
    current="$(readlink "$link" || true)"
    [[ "$current" == "$target" ]] && return 0
    rm -f "$link"
  elif [[ -d "$link" ]]; then
    # Copy old in-container data into the newly mounted volume on upgrade.
    cp -a "$link/." "$target/" 2>/dev/null || true
    rm -rf "$link"
  elif [[ -e "$link" ]]; then
    rm -f "$link"
  fi
  ln -s "$target" "$link"
}

persist_directory "$DATA_DIR/workspace" /workspace
persist_directory "$DATA_DIR/projects" /root/projects
persist_directory "$DATA_DIR/.pm2" /root/.pm2

export WORKSPACE=/workspace
export PM2_HOME="$DATA_DIR/.pm2"
export NPM_CONFIG_PREFIX="$DATA_DIR/.npm-global"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

# Persist server host keys, so SSH fingerprints remain stable after redeploy.
if [[ ! -s "$DATA_DIR/ssh/ssh_host_ed25519_key" || ! -s "$DATA_DIR/ssh/ssh_host_ed25519_key.pub" ]]; then
  rm -f "$DATA_DIR/ssh/ssh_host_ed25519_key" "$DATA_DIR/ssh/ssh_host_ed25519_key.pub"
  ssh-keygen -q -t ed25519 -N '' -f "$DATA_DIR/ssh/ssh_host_ed25519_key"
fi
if [[ ! -s "$DATA_DIR/ssh/ssh_host_rsa_key" || ! -s "$DATA_DIR/ssh/ssh_host_rsa_key.pub" ]]; then
  rm -f "$DATA_DIR/ssh/ssh_host_rsa_key" "$DATA_DIR/ssh/ssh_host_rsa_key.pub"
  ssh-keygen -q -t rsa -b 3072 -N '' -f "$DATA_DIR/ssh/ssh_host_rsa_key"
fi
chmod 0600 "$DATA_DIR/ssh/ssh_host_ed25519_key" "$DATA_DIR/ssh/ssh_host_rsa_key"
chmod 0644 "$DATA_DIR/ssh/ssh_host_ed25519_key.pub" "$DATA_DIR/ssh/ssh_host_rsa_key.pub"
install -o root -g root -m 0600 "$DATA_DIR/ssh/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
install -o root -g root -m 0644 "$DATA_DIR/ssh/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub
install -o root -g root -m 0600 "$DATA_DIR/ssh/ssh_host_rsa_key" /etc/ssh/ssh_host_rsa_key
install -o root -g root -m 0644 "$DATA_DIR/ssh/ssh_host_rsa_key.pub" /etc/ssh/ssh_host_rsa_key.pub

write_authorized_keys() {
  local target_dir="$1" key_text="$2"
  [[ -n "$key_text" ]] || return 0
  mkdir -p "$target_dir"
  printf '%s\n' "$key_text" | sed '/^[[:space:]]*$/d' > "$target_dir/authorized_keys"
  chmod 0700 "$target_dir"
  chmod 0600 "$target_dir/authorized_keys"
}

write_authorized_keys /root/.ssh "$AUTHORIZED_KEYS"
if [[ -n "$SSH_USERNAME" && -n "$SSH_USER_AUTHORIZED_KEYS" ]]; then
  user_home="$(getent passwd "$SSH_USERNAME" | cut -d: -f6)"
  [[ -n "$user_home" ]] || die "Could not determine home directory for ${SSH_USERNAME}."
  write_authorized_keys "${user_home}/.ssh" "$SSH_USER_AUTHORIZED_KEYS"
  chown -R "$SSH_USERNAME:$SSH_USERNAME" "${user_home}/.ssh"
fi

root_key_available=false
user_key_available=false
[[ -s /root/.ssh/authorized_keys ]] && root_key_available=true
if [[ -n "$SSH_USERNAME" ]]; then
  user_home="$(getent passwd "$SSH_USERNAME" | cut -d: -f6)"
  [[ -n "$user_home" && -s "${user_home}/.ssh/authorized_keys" ]] && user_key_available=true
fi
password_auth_enabled=false
is_true "$SSH_PASSWORD_AUTH" && password_auth_enabled=true || true
root_login_enabled=true
[[ "${SSH_ROOT_LOGIN,,}" == no ]] && root_login_enabled=false

if [[ "$password_auth_enabled" == false ]]; then
  [[ "$root_login_enabled" == true && "$root_key_available" == true ]] \
    || [[ -n "$SSH_USERNAME" && "$user_key_available" == true ]] \
    || die 'Password login is disabled but no usable authorized key is configured. Add AUTHORIZED_KEYS or SSH_USER_AUTHORIZED_KEYS.'
fi
if [[ "$root_login_enabled" == false && "$password_auth_enabled" == false && "$user_key_available" == false ]]; then
  die 'Root login and password login are disabled, and the secondary user has no authorized key.'
fi
if [[ "${SSH_ROOT_LOGIN,,}" == no && -z "$SSH_USERNAME" ]]; then
  die 'SSH_ROOT_LOGIN=no requires a secondary SSH_USERNAME/SSH_PASSWORD account.'
fi
if [[ "${SSH_ROOT_LOGIN,,}" == prohibit-password && ! -s /root/.ssh/authorized_keys && -z "$SSH_USERNAME" ]]; then
  die 'SSH_ROOT_LOGIN=prohibit-password requires root AUTHORIZED_KEYS or a secondary user.'
fi
if [[ "${SSH_ROOT_LOGIN,,}" == prohibit-password && "$password_auth_enabled" == false && "$root_key_available" == false && "$user_key_available" == false ]]; then
  die 'SSH_ROOT_LOGIN=prohibit-password needs authorized keys when password login is disabled.'
fi

# Replace the default config with one explicit file. This avoids cloud-init
# drop-ins or image defaults silently overriding our authentication settings.
mkdir -p /run/sshd
cat > /etc/ssh/sshd_config <<SSH_CONF_EOF
Port 22
AddressFamily any
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
PermitRootLogin ${SSH_ROOT_LOGIN}
PasswordAuthentication ${SSH_PASSWORD_AUTH,,}
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding yes
PermitTunnel no
GatewayPorts no
ClientAliveInterval 60
ClientAliveCountMax 5
LoginGraceTime 30
MaxAuthTries 4
MaxSessions 20
MaxStartups 10:30:100
PermitUserEnvironment no
UseDNS no
LogLevel INFO
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp internal-sftp
SSH_CONF_EOF

if [[ -n "$SSH_USERNAME" ]]; then
  printf 'AllowUsers root %s\n' "$SSH_USERNAME" >> /etc/ssh/sshd_config
else
  printf 'AllowUsers root\n' >> /etc/ssh/sshd_config
fi

if [[ -n "$SSH_USERNAME" ]]; then
  visudo -cf /etc/sudoers >/dev/null
fi

sshd -t || die 'OpenSSH configuration validation failed. Check the startup logs.'
log 'SSH configuration validated.'

# Automatically restore processes previously saved with `pm2 save`.
if [[ -s "$PM2_HOME/dump.pm2" ]]; then
  log 'Restoring saved PM2 processes...'
  if ! pm2 resurrect; then
    log 'WARNING: PM2 restore failed. SSH will still start; inspect PM2 logs.'
  fi
fi

log 'Starting SSH server on port 22.'
exec /usr/sbin/sshd -D -e
