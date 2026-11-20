# Changelog

## 2.0.2 — Railway input form fixes

- Add a Railway setup guide explaining that deploy-time prompts are configured in the Template Composer Variables tab, not imported automatically from `railway-template.json`.
- Expand `.env.example` so Railway can suggest all supported variables for import.
- Add `VALZZ_HOSTNAME` as a dedicated custom hostname variable to avoid collision with the container runtime's built-in `HOSTNAME`.
- Pass optional SSH user, key, sudo, and Node options through Docker Compose.
- Document `ROOT_PASSWORD` and `VALZZ_HOSTNAME` as the two required deploy-time inputs.


## 2.0.1 — Valzz branding

- Normalize project branding and internal identifiers to Valzz across startup scripts, service names, terminal labels, and backup filenames.
- Update Railway template documentation and replace the upstream repository URL with a clearly marked GitHub username placeholder.
- Preserve the upstream MIT copyright notice and identify Valzz modifications separately.


## 2.0.0 — Persistent Edition

- Keep Ubuntu 24.04 and move runtime to Node.js 26 LTS.
- Replace the inherited SSH configuration with one explicit, validated configuration.
- Add SSH password/key controls and stricter secondary-user validation.
- Default secondary sudo access to password-required.
- Persist workspace, projects, root PM2 state, global npm packages, secondary home directories, and SSH host keys under `/data`.
- Restore root PM2 processes saved with `pm2 save`.
- Add `server-status`, `backup-data`, and Docker TCP healthcheck scripts.
- Add local Docker Compose setup and deployment guidance.
