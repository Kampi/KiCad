# Project Guidelines

KiCad library (symbols, footprints, 3D models, design blocks) with a project template and init scripts that create new KiCad projects from it. User documentation is in [README.md](README.md), the development workflow in [KiCad Workflow.md](KiCad%20Workflow.md). Link to them instead of repeating their content.

This file is the single source of the project guidelines for all AI coding agents. Tool-specific files only point to it:
[.github/copilot-instructions.md](.github/copilot-instructions.md) (GitHub Copilot) and [CLAUDE.md](CLAUDE.md) (Claude Code).
Change the guidelines here, not in those files.

## Scoped Rules

Read the matching rule file completely before changing a file in its scope. GitHub Copilot applies these files
automatically through their `applyTo` front matter, all other agents must open them themselves.

| Scope | Rule file |
| ----- | --------- |
| `Scripts/**` (init scripts) | [.github/instructions/init-scripts.instructions.md](.github/instructions/init-scripts.instructions.md) |
| `Template-Project/.github/workflows/**`, `Template-Project/.gitlab/**`, `Template-Project/.gitlab-ci.yml` (CI/CD pipelines) | [.github/instructions/ci-pipelines.instructions.md](.github/instructions/ci-pipelines.instructions.md) |

A new rule file needs the `description` and `applyTo` front matter and a row in this table.

## Architecture

- `Scripts/init-project.sh`, `Scripts/init-project.ps1`: Create a project from `Template-Project/` (copy, apply the project type and the PCB template, rename `hardware/` to the lowercase board name, replace the `${...}` placeholders, initialize Git).
- `Template-Project/` (Git submodule): Template for new projects
  - `hardware/`: KiCad project, KiBot configuration (`kibot_yaml/`), `CHANGELOG.md`, `kibot_launch.sh` and the PCB templates `Template - <manufacturer>_<thickness>_<layers>-layer.kicad_pcb`
  - `.github/workflows/`, `.gitlab/ci/`: CI/CD pipelines.
  - `.github/skills/create-dev-branch/`, `.github/skills/create-release/`: Agent skills for development branches and hardware releases. Keep them in sync: `create-dev-branch` prepares the state `create-release` expects
  - `.claude/skills/`: Pointers to the skills in `.github/skills/` for Claude Code. They contain no steps, only the same `name` and `description`. A new skill needs a pointer here
  - `firmware/`: Firmware profiles, the init scripts keep one of them: `blank`, `platformio` (ESP32, ESP-IDF via PlatformIO) and `esp-idf-component` (moved to the repository root)
  - `scripts/`: Helper scripts of the generated projects (changelog, format)
- `GitHub/`, `Plugins/`: Third-party Git submodules. Don't edit them

## Conventions

- KiCad 10.0 or later only. Don't add compatibility code for older KiCad versions. KiBot runs in `ghcr.io/inti-cmnb/kicad10_auto_full:latest`
- Keep these pairs in sync and never change only one side:
  - `init-project.sh` and `init-project.ps1`
  - Each GitHub Actions workflow and its GitLab CI pipeline
- Versions are SemVer: development branches `x.y.z_Dev`, release tags `x.y.z` without `v` prefix
- KiBot variants: `DRAFT`, `PRELIMINARY` (set by the `create-dev-branch` skill), `CHECKED` (set by the `create-release` skill), `RELEASED` (tag pushes)
- `CHANGELOG.md` format, validated by the changelog pipelines:

  ```markdown
  ## [Unreleased]

  **Added:**

  - New feature (#12)

  **Fixed:**

  - Bug fix (#13)
  ```

  Allowed sections: `**Added:**`, `**Changed:**`, `**Fixed:**`, `**Removed:**`. Every entry starts with `- ` and references an issue

## Documentation

- Update [README.md](README.md) for every user-facing change of the init scripts, the template, the pipelines, the secrets or the skill
- English only, no emojis

## Commits

- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`
- Commit both sides of a synced pair together
