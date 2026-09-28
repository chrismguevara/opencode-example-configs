# Using the project template

`project-template/` is what a software project gets; `opencode/` is what your
user account gets. Keep them separate: the template must not redefine models
or agents, and the global config must not carry project conventions.

```
project-template/
├── opencode.jsonc        # formatters (oxfmt, gofmt), generated-dir protection
├── AGENTS.md             # stack conventions (React/TanStack/Valibot/shadcn/Cesium/MapLibre/Turf/Go/contracts)
└── .agents/skills/       # on-demand Agent Skills, one folder per skill
    ├── tanstack-router/SKILL.md
    ├── tanstack-start/SKILL.md
    ├── valibot/SKILL.md
    ├── shadcn/SKILL.md
    ├── cesium/SKILL.md
    ├── turf/SKILL.md
    ├── api-contracts/SKILL.md
    ├── playwright/SKILL.md
    └── go-backend/SKILL.md
```

## Install into a project

Scripted (detects conflicts, never overwrites silently):

```bash
./scripts/install-project-template.sh /path/to/project --dry-run
./scripts/install-project-template.sh /path/to/project
./scripts/install-project-template.sh /path/to/project --cline-symlink   # optional, see below
```

Existing files that differ are reported as `CONFLICT` and left alone; add
`--force` to replace them after a timestamped backup. Identical files are
skipped, so re-running is safe.

Manual equivalent:

```bash
cd /path/to/project
cp -n  /path/to/opencode-example-configs/project-template/AGENTS.md .
cp -n  /path/to/opencode-example-configs/project-template/opencode.jsonc .
mkdir -p .agents
rsync -a --ignore-existing /path/to/opencode-example-configs/project-template/.agents/ .agents/
```

Then in the project:

1. Trim `AGENTS.md` to the technologies the project actually uses.
2. Add `oxfmt` as a devDependency if the project has JS/TS (`docs/INSTALL.md`).
3. Run `opencode debug skill` inside the project; all nine skills should be listed.
4. Commit `AGENTS.md`, `opencode.jsonc`, and `.agents/skills/` so the team shares them.

## Skills philosophy

Skills hold project conventions, version notes, paths/links to authoritative
references, workflows, and known pitfalls. They are loaded on demand by the
`skill` tool, so they cost nothing until needed.

Do not paste whole external documentation into a skill and do not clone
documentation trees into every project. If a reference repository is really
needed later, pin it to a commit or version tag, never `main`, and keep it
out of the initial setup.

Skill rules (enforced by OpenCode and `scripts/validate.sh`):

- frontmatter with `name` and `description` (1-1024 chars)
- `name` is lowercase kebab-case and equals the directory name
- unique names across global and project locations

## Cline compatibility

Some teammates use Cline. The canonical skill directory stays `.agents/skills`
(which OpenCode reads natively). Cline's current documentation lists
`.cline/skills/`, `.clinerules/skills/`, and `.claude/skills/` as project
skill locations, not `.agents/skills/`, so the optional compatibility link is:

```
.cline/skills -> ../.agents/skills
```

Create it with `--cline-symlink` or `mkdir -p .cline && ln -s ../.agents/skills .cline/skills`.
Skills are not duplicated; the symlink is the only extra file. Confirm once in
a real project that your Cline version follows the symlink, and re-check
Cline's docs if its discovery paths change.
