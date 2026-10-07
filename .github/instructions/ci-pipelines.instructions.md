---
description: "Use when editing CI/CD pipelines of the project template: GitHub Actions workflows, GitLab CI pipelines, KiBot PCB pipeline, secrets and CI/CD variables."
applyTo: "Template-Project/.github/workflows/**, Template-Project/.gitlab/**, Template-Project/.gitlab-ci.yml"
---
# CI/CD Pipelines

Every pipeline exists for GitHub Actions and GitLab CI. Change both files together:

| Pipeline | GitHub Actions | GitLab CI |
| -------- | -------------- | --------- |
| PCB (KiBot) | `hw-pcb.yaml` | `pcb.gitlab-ci.yml` |
| Changelog check | `common-changelog.yaml` | `changelog.gitlab-ci.yml` |
| Documentation | `docs-build.yaml` | `documentation.gitlab-ci.yml` |
| Code style check (AStyle) | `fw-format.yaml` | `astyle.gitlab-ci.yml` |
| Code style check (West) | - | `west-astyle.gitlab-ci.yml` |
| PlatformIO firmware | `fw-platformio.yaml` | - |
| ESP-IDF component | `fw-esp-component.yaml` | - |
| Component release (ESP-IDF) | `fw-esp-component-release.yaml` | `esp-component-release.gitlab-ci.yml` |

- Add new GitLab pipelines to the `include:` list of `Template-Project/.gitlab-ci.yml`
- File names: lowercase with hyphens, `.yaml` for GitHub Actions, `.gitlab-ci.yml` for GitLab CI
- GitHub Actions workflows are grouped by area: file prefix `hw-`, `fw-`, `docs-` or `common-` and the matching workflow name `Hardware / ...`, `Firmware / ...`, `Documentation / ...` or `Common / ...`
- The init scripts select the workflows by these names: `hw-*.yaml` is removed without hardware, `fw-platformio.yaml` and `fw-esp-component*.yaml` without the matching firmware profile, `docs-*.yaml` for the ESP-IDF component. Update `Set-ProjectType` / `apply_project_type` when adding or renaming a workflow
- Restrict `hw-` and `fw-` workflows with `paths` filters to their area. Path filters are not evaluated for tag pushes
- `hw-pcb.yaml` is not triggered by the main branch. A release is built by its tag, and GitHub Pages is only deployed by tag runs, so it always shows the latest release. Don't add `main` / `master` to its branch triggers
- `fw-platformio.yaml` and `fw-esp-component.yaml` have no GitLab CI pipeline yet
- Every file starts with the header comment block (Trigger, Function, Variables, Secrets). Keep it up to date
- Configuration at workflow level: GitHub `env:` in lowercase (`kibot_input_dir`), GitLab `variables:` in uppercase (`KIBOT_INPUT_DIR`). Values set by the init scripts are `${UPPERCASE}` placeholders
- A value used in several pipelines (e.g. the main branch) must be changed in all GitHub and GitLab files
- KiBot jobs use the image `ghcr.io/inti-cmnb/kicad10_auto_full:latest`
- The `create-release` skill uses the file name `hw-pcb.yaml` and its `env` keys `kibot_input_dir`, `kicad_board`, `master_branch` and `kibot_variant`. Update the skill when renaming them
- Document new pipelines, secrets and variables in [README.md](../../README.md) (CI/CD Pipelines, GitHub Secrets Configuration, GitLab CI/CD Variables)

## Platform Differences

| Concept | GitHub Actions | GitLab CI |
| ------- | -------------- | --------- |
| Tag push | `github.ref_type == 'tag'` | `CI_COMMIT_TAG` |
| Branch name | `github.ref_name` | `CI_COMMIT_BRANCH` |
| Repository URL | `github.server_url` + `github.repository` | `CI_PROJECT_URL` |
| Token for pushes and releases | `GITHUB_TOKEN` | `WORKFLOW_PAT` (CI/CD variable) |
| Secrets | Repository secrets | Masked CI/CD variables |
| Artifacts | `actions/upload-artifact` | `artifacts:` |
| Pages | `actions/deploy-pages` | `pages` job with `public/` |
