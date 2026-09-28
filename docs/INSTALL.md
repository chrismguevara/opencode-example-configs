# Installing on a Rocky Linux development host

This guide prepares a Rocky Linux 9 (or 10) machine for the configuration in
this repository. It assumes the machine may already have some tools:
**check before installing** and do not reinstall what is present. `mise` is
not used.

Preference order: `dnf` from the base/AppStream repos, then EPEL, then
official vendor RPM repositories, then an official release binary/RPM. No
curl-pipe-shell installers unless there is no packaged alternative.

## 0. Check what is already there

```bash
for t in git node npm pnpm go glab playwright-cli oxfmt opencode; do
  printf '%-15s ' "$t"; command -v "$t" >/dev/null 2>&1 && "$t" --version 2>/dev/null | head -1 || echo missing
done
```

## 1. Git

```bash
git --version || sudo dnf install -y git
```

## 2. Node.js and a JavaScript package manager

Node 22 (current LTS line) is available as an AppStream module stream:

```bash
node --version || { sudo dnf module enable -y nodejs:22 && sudo dnf install -y nodejs npm; }
```

If a project uses pnpm, yarn, or bun, use that project's manager as it
documents it (for example `corepack enable && corepack prepare pnpm@latest --activate`,
which ships with Node). Do not force npm on a pnpm/yarn/bun project.

For global npm installs without `sudo`, set a user prefix once:

```bash
npm config set prefix "$HOME/.local"
# ensure $HOME/.local/bin is on PATH (e.g. in ~/.bashrc)
```

## 3. Go

Rocky's AppStream `golang` package can lag behind what `go.mod` files require.
Check first:

```bash
go version || sudo dnf install -y golang
```

If your projects need a newer Go than AppStream provides, install the
official tarball from https://go.dev/dl/ into `/usr/local/go` (this is the
Go project's own supported method; there is no newer vendor RPM repo) and add
`/usr/local/go/bin` to `PATH`. Keep only one Go on `PATH`.

Go lint tooling: use what the repository configures. If a project has
`.golangci.yml`, install golangci-lint per its docs (a release binary in
`$(go env GOPATH)/bin` or `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@<version>`
pinned to the version the repo expects). If it uses `staticcheck`, `go install
honnef.co/go/tools/cmd/staticcheck@<version>`. The project's configuration wins.

## 4. glab (GitLab CLI)

Check first; if present, keep it:

```bash
glab --version
glab auth status
```

Install options, in preference order:

1. **EPEL/dnf.** `glab` is packaged in Fedora. Enable EPEL and try dnf:

   ```bash
   sudo dnf install -y epel-release
   sudo dnf install -y glab
   ```

   If dnf reports no such package for your Rocky release, use option 2.

2. **Official release RPM.** GitLab publishes `.rpm` files for every release
   at https://gitlab.com/gitlab-org/cli/-/releases (for example
   `glab_<version>_linux_amd64.rpm`). Download the RPM for your architecture
   and install it with `sudo dnf install ./glab_<version>_linux_amd64.rpm`.
   This is used only because there is no vendor dnf repository; it is still a
   signed package install, not a curl-pipe-shell.

Authenticate yourself (this repository never does it for you), for gitlab.com
or a Self-Managed instance:

```bash
glab auth login                       # gitlab.com
glab auth login --hostname gitlab.example.com   # self-managed
glab auth status
```

Use a token scoped to `read_api` (and `read_repository` if needed): the
`gitlab` agent is read-only by configuration, and a read-only token enforces
that at the server. See `SECURITY.md`.

## 5. Playwright CLI

The browser agent uses the **Playwright CLI** (`playwright-cli`, npm package
`@playwright/cli`), not the Playwright MCP server.

```bash
npm install -g @playwright/cli@latest
playwright-cli --help
playwright-cli --version
```

The CLI drives a browser; if no supported browser is found on first use, follow
the CLI's own message to install one (`playwright-cli --help` documents
`--browser`). Smoke test against a site you are allowed to test:

```bash
playwright-cli open https://example.com
playwright-cli snapshot
playwright-cli screenshot
playwright-cli close
```

Do not run browser operations against sites you are not authorized to test.

## 6. Oxfmt (per project, not global)

Oxfmt replaces Prettier in the project template. Install it with the
project's own package manager as a dev dependency:

```bash
npm install -D oxfmt      # or: pnpm add -D oxfmt / yarn add -D oxfmt / bun add -d oxfmt
```

Validate:

```bash
npx --no-install oxfmt --check .      # or the project's format script
```

`project-template/opencode.jsonc` runs `npx --no-install oxfmt --write "$FILE"`
after edits, which only works when oxfmt is installed in the project.
Remove Prettier from the project when migrating (`oxfmt --migrate=prettier`
can convert an existing Prettier config).

## 7. OpenCode

OpenCode's documented install methods are the official install script
(`curl -fsSL https://opencode.ai/install | bash`), npm/pnpm/bun/yarn
(`npm install -g opencode-ai`), Homebrew, Arch packages, and Docker. There is
no RPM repository. On Rocky, prefer the npm package since Node is already
installed and npm is a package manager you can audit and upgrade:

```bash
npm install -g opencode-ai@latest
opencode --version          # this configuration targets 1.18.x or newer 1.x
```

Then:

```bash
./scripts/install.sh --dry-run   # review
./scripts/install.sh             # symlink opencode/ into ~/.config/opencode/
opencode providers login         # or /connect in the TUI; authenticate OpenAI and your GPT-OSS provider
./scripts/check-models.sh        # confirm model IDs
./scripts/validate.sh
```

Upgrade later with `npm install -g opencode-ai@latest` (or `opencode upgrade`).

## 8. Optional: shellcheck

`scripts/validate.sh` runs shellcheck when present: `sudo dnf install -y ShellCheck` (EPEL).
