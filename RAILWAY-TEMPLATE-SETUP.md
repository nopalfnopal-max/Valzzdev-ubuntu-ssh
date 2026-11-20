# ValzzHost — setup form input Railway Template

Railway templates are authored in the Railway dashboard Template Composer. The repository manifest `railway-template.json` is reference metadata; it is not automatically imported by the current visual composer.

## Configure the service

1. Open the draft in Railway **Template Composer**.
2. Select the GitHub service that points to this repository.
3. Open its **Variables** tab.
4. Use **Raw Editor** and paste:

```env
ROOT_PASSWORD=
VALZZ_HOSTNAME=valzzhost
SSH_PASSWORD_AUTH=true
SSH_ROOT_LOGIN=yes
SSH_USERNAME=
SSH_PASSWORD=
AUTHORIZED_KEYS=
SSH_USER_AUTHORIZED_KEYS=
SSH_SUDO_NOPASSWD=false
NODE_OPTIONS=
```

5. Save/update the variables.
6. Open each variable's settings and set the properties below.

| Key | Required | Secret | Suggested description |
|---|---:|---:|---|
| `ROOT_PASSWORD` | Yes | Yes | Required SSH root password. Use a unique strong password. |
| `VALZZ_HOSTNAME` | Yes | No | Linux hostname shown by the server. Example: valzzhost. |
| `SSH_PASSWORD_AUTH` | No | No | Enable SSH password authentication; default true. |
| `SSH_ROOT_LOGIN` | No | No | Root SSH login mode: yes, no, or prohibit-password. |
| `SSH_USERNAME` | No | No | Optional extra SSH account username; requires SSH_PASSWORD. |
| `SSH_PASSWORD` | No | Yes | Password for the optional extra SSH account. |
| `AUTHORIZED_KEYS` | No | Yes | SSH public key(s) for root. |
| `SSH_USER_AUTHORIZED_KEYS` | No | Yes | SSH public key(s) for the extra user. |
| `SSH_SUDO_NOPASSWD` | No | No | Allow passwordless sudo for extra user; default false. |
| `NODE_OPTIONS` | No | No | Optional Node.js runtime flags. |

7. Ensure `ROOT_PASSWORD` and `VALZZ_HOSTNAME` have **Required** enabled. Save the template draft.
8. Use the template's preview/deploy flow to verify those two values are requested before publishing.

## Important distinction

- `.env.example` helps Railway detect/suggest variable names from the repository.
- `railway-template.json` documents the intended settings for this project.
- The variables shown in the marketplace **Deploy** form are controlled by the Template Composer's service Variables configuration, including Required, Secret, and descriptions.

## Hostname variable

Use `VALZZ_HOSTNAME`, not the generic `HOSTNAME` key. Container runtimes commonly set `HOSTNAME` automatically, so using a dedicated key avoids confusing the generated container hostname with the custom hostname selected by the deployer.
