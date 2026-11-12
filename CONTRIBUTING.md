# Contributing to moocp

How we work on moocp. For architecture, building and testing see the developer handbook in the [README](README.md) (part 4, in German). Decisions about the program itself are recorded as ADRs in `docs/adr/`; this file covers how we collaborate.

Everything on GitHub (issues, pull requests, commits, branch names, labels) is written in English. The README, the changelog and all texts shown in the app stay German, because the users are German teachers.

## Principles

- One shared repository, no forks. Everyone with write access works on short-lived branches.
- `main` is protected: changes only via pull request (PR), never a force-push, never a rewrite of history.
- Everyone can start and build their own things without asking first. The only gate is the review before a merge.
- Work is split by feature, never by platform. There are no `windows` or `macos` branches. A platform is described with labels and in the issue.

## Contributing or building a plugin

There are two ways to add something, and both are welcome:

- **Contribute to moocp.** If a feature belongs in moocp itself, open an issue here. Once accepted, it is part of moocp, covered by its guarantees, and discussed here like everything else.
- **Build a plugin.** If you want to develop independently, build a plugin in your own project, with its own repository, issues and releases. You do not need to ask first. The plugin interface is described in the README (part 4).

A plugin is the responsibility of its own project. This repository, its issues and its pull requests therefore contain nothing about a particular plugin and nothing about features that only a plugin has. Questions and requests about the plugin interface itself belong here, described by what the interface has to do in general, not by one use case.

## Issues

- Every piece of work starts as an issue. Small obvious fixes may go straight to a PR.
- Use the issue templates. State which systems are affected: *confirmed* (you tried it), *suspected* or *unknown*.
- Do not put real instance addresses, school names, course numbers or personal data in issues or PRs (the repository is public).

### Labels

| Group | Labels |
|---|---|
| Triage | `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` |
| Kind | `bug`, `enhancement`, `refactoring`, `documentation`, `question` |
| Platform | `os:windows`, `os:macos`, `os:linux`, `os:all`, `os:unclear` |

A platform label is set by the person who knows. With `os:unclear` also set `needs-info`; whoever reproduces or fails to reproduce the problem on another system comments and corrects the label. For a given system, the person who tested on it has the last word.

## Branches

Create a branch from an up-to-date `main`, named `<kind>/<issue-number>-<short-slug>`:

`fix/42-backup-no-user-data`, `feat/17-linux-bridge`, `docs/contributing`, `chore/…`, `refactor/…`.

- One issue, one branch, one PR. A PR contains one complete feature or fix, so nobody needs three PRs to understand one change.
- Size is a guideline, not a rule. Up to roughly 2000 changed lines is normal; beyond that ask whether the change can be sliced. Slices should be mergeable on their own, and unfinished work is simply not wired in yet.
- Only if a feature cannot be sliced, use an integration branch `feat/<name>`. Sub-PRs target that branch, and one final PR goes to `main`. Sub-branches exist only below an integration branch. Merge `main` into it regularly.
- Keep your branch current by merging `main` into it. Never rebase commits you have already pushed.
- Delete the branch after the merge.

## Pull requests

- The title says what changes for the user or the maintainer; it ends up in the history.
- The description says what and why, links the issue (`Closes #42`) and names what you tested and on which system.
- If a conversation would be easier than comments, say so in the PR ("a call might help").
- User-visible changes get one line under the upcoming version in `CHANGELOG.md` (German, see the rules in `CLAUDE.md`).
- Run `flutter analyze` and `flutter test` before opening the PR.

## Review and merge

- Every PR needs a review by the other maintainer. Nobody merges their own PR without it, and there is no deadline after which that changes. If the other person is away, the PR waits, or the other one takes over the work.
- `.github/CODEOWNERS` requests the review automatically. It also marks the areas where a careful second look is mandatory:
  - the blocklist and allowlist (`sperrliste.dart`, `moodle_zugang.dart`, `browserliste.dart`),
  - approval logic (`freigabe.dart`) and credentials (`anmeldedaten.dart`, `anmeldung.dart`),
  - installer and update (`installer/`, `lib/update/`),
  - `CLAUDE.md`, `AGENTS.md` and the ADRs.
- Merge method: **merge commit** by default, so every single commit stays traceable. **Squash** only if the history of the branch is messy. **No rebase merge.** A PR can be traced on GitHub even after its branch is deleted.
- Review with the help of an AI is fine; a human still looks at the whole change.
- If one of us is away for a longer time, the other carries on and leaves a short note in the affected issue or PR about what changed in the meantime.

## Communication

- Decisions are made in the issue or PR, with an `@` mention so the other one is notified. Set the other maintainer as reviewer.
- Fundamental questions are discussed by phone or mail first, and the result is written down in the issue, a PR or an ADR.
- GitHub Discussions are off. We switch them on if discussions get too big for issues.

## Releases

A version is created on `main` once everything for it is merged: version in `pubspec.yaml`, section in `CHANGELOG.md`, tag `v<version>`, then a release from that tag. Details are in the README (part 4, "Veröffentlichen").
