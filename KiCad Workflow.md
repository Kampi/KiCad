# KiCad Workflow

## Table of Contents

- [KiCad Workflow](#kicad-workflow)
  - [Table of Contents](#table-of-contents)
  - [Related files](#related-files)
    - [Project template](#project-template)
    - [Commit message template](#commit-message-template)
  - [Create a new project](#create-a-new-project)
  - [Version Numbering](#version-numbering)
    - [Major](#major)
    - [Minor](#minor)
    - [Fix](#fix)
  - [GitHub workflow](#github-workflow)
    - [Milestones](#milestones)
    - [Issue tracker](#issue-tracker)
    - [Types](#types)
      - [Bug](#bug)
      - [Feature](#feature)
      - [Task](#task)
  - [Working with the Issue Tracker](#working-with-the-issue-tracker)
    - [Branch Workflow](#branch-workflow)
  - [Publishing a New Release](#publishing-a-new-release)
  - [Maintainer](#maintainer)

## Related files

### Project template

You can find a ready-to-use project template in `__Project__` directory of the [KiCad library](https://github.com/Kampi/KiCad) project.

### Commit message template

The commit message for a feature or bug fix must look like this (you can use `git commit -s` to add the `Signed-off-by` text):

```txt
<Type>: Issue #<Number>

(If needed) Description of changes

Closes ...

Signed-off-by: Your name <Your Email>
```

You can find a commit message template in the `github` directory of the project. Open a git shell in the project directory and use the command

```sh
git config commit.template .github/.commit-msg-template
```

to change the template locally for the project. If no template is available, feel free to create one yourself.

## Create a new project

1. Copy the template project (`__Project__`) and rename it
2. Rename the KiCad files in `hardware` according to your project
3. Open `.github/workflows/pcb.yaml`

    - Replace the variables in the `env` section according to your project

4. (Optional): If you want to use a logo, replace and rename `dummy_logo.png` in `Logos` with your logo. Then change the logo path in `hardware/README.md` and `hardware/kibot_yaml/kibot_main.yaml`
5. Open `hardware/kibot_yaml/kibot_main.yaml` to replace the following text variables:

| Variable | Description |
|:----|:-----|
| PROJECT_NAME | The name of the KiCad project |
| BOARD_NAME | The name of the project |
| COMPANY | Your company name |
| DESIGNER | The name of the board designer |
| LOGO | The path to your logo (if needed) |
| GIT_URL | The URL to the Git repository |

## Version Numbering

Format: `Major.Minor.Fix`

### Major

Increment when the hardware architecture or overall project structure changes significantly.

### Minor

Increment when new features or major improvements are introduced.

### Fix

Increment for minor bug fixes, layout corrections, or documentation updates.

## GitHub workflow

### Milestones

A **milestone** is created for every release and is used to group related features and bug fixes.
The naming convention is:

```txt
<Project> Version <Major> Release <Minor> (Fix <Fix>)
```

Example:

```txt
Watch-DK Version 1 Release 2
````

A new development branch named `<Major>.<Minor>.<Fix>_Dev` is created from the main branch for this milestone.
When this branch is initialized:

- The KiBot workflow state in the CI/CD configuration is set to `PRELIMINARY`.
- Production files from the previous version are removed.

The initial commit message must be:

```txt
Initialize development branch for version <Major>.<Minor>.<Fix>

Signed-off-by: Your name <Your Email>
```

> **NOTE** 
> You can use the `create-dev-branch` script from `.github/scripts` to run these steps automatically.

### Issue tracker

The **issue tracker** is used to manage all bugs, features, and tasks.
Each issue must:

Be assigned to a specific milestone.

Have the correct type and labels.

### Types

#### Bug

An error or flaw in the design (schematic or PCB layout). Documentation issues do **not** count as bugs.

#### Feature

A new functionality or an enhancement of an existing one.

#### Task

General to-dos such as documentation improvements, refactoring, or cleanup tasks.

## Working with the Issue Tracker

All features and bug fixes are developed in the development branch of their assigned milestone.
Each commit affecting the PCB project must also include an entry in the [Unreleased] section of the `CHANGELOG.md` file:

```txt
- <Short description> (#<Issue number>)
```

Entries should be placed under the correct category:

- `Fix`
- `Added`
- `Removed`
- `Changed`

### Branch Workflow

You can either:

- Fork the development branch, commit your changes there, and open a PR, or
- Create a feature branch from the development branch, make your changes, and open a PR from that branch.

The KiBot workflow state may be set to `DRAFT` or `PRELIMINARY` as needed, but **must not** be set to `CHECKED`.

### Initialization of the development branch

A development branch is created from the `main` branch. The first commit should always remove the production files and reset the workflow state to `DRAFT` or `PRELIMINARY`. The first commit message is always

```sh
Initialize development branch for version ...
```

## Publishing a new Release

A new release is pushed to `main` by using a Pull Request. The request can be created as a draft either when a new development branch is created or later, when all the work is done. The title of the Pull Request should always be `Release <Major>.<Minor>.<Fix>`.

To prepare a new release:

1. Create a commit in the development branch with the header:

```sh
Release <Major>.<Minor>.<Fix>
```

2. Update all release-specific data:

- Set the release title and body in the schematic’s **Revision History** page:
- Change RELEASE_TITLE_... → RELEASE_TITLE_<Major>.<Minor>.<Fix>
- Update the changelog variables in kibot_pre_set_text_variables.yaml.

3. Fix all **ERC** and **DRC** errors.
4. Set the KiBot workflow to `CHECKED`.
5. Push all changes to the feature branch.
6. Merge the feature branch into the main branch.
7. Create and push a new Git tag for the version:

```sh
git pull <Upstream> <Main>
git tag <Major.Minor.Fix>
git push <Upstream> <Major.Minor.Fix>
```

## Maintainer

- [Daniel Kampert](mailto:DanielKampert@kampis-elektroecke.de)
