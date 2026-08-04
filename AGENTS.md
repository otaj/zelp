# Agent notes (Zelp)

## Git worktrees + FVM (required)

`.fvm/` is gitignored. A new worktree has `.fvmrc` but **no** SDK symlink.
You must bind FVM and resolve pubs before any `fvm flutter` / `fvm dart` /
pre-commit / test.

### Root cause of cache corruption

pre-commit (and some agent shells) export `GIT_DIR` / `GIT_INDEX_FILE` /
`GIT_WORK_TREE` for the **Zelp** worktree. FVM and Flutter run `git` inside
the shared SDK clone at `~/fvm/versions/<pin>`. With those vars set, `git`
reads Zelp instead of the SDK: Flutter reports Zelp's HEAD as its framework
revision (`channel [user-branch]`, `0.0.0-unknown`), and FVM "auto-repairs" by
**deleting and reinstalling** the shared pin — breaking every worktree and the
main clone. Concurrent hook installs make it worse.

All FVM invocations in this repo must go through `scripts/run_fvm.sh`, which
unsets those variables.

### Create a worktree

```bash
# 1) Pin is already installed once (from main or any healthy worktree)
./scripts/run_fvm.sh install          # reads .fvmrc; no-op if cache is healthy

# 2) Add the worktree
git fetch origin master
git worktree add -b <branch> /home/otaj/.cursor/worktrees/zelp/<name> origin/master

# 3) BEFORE any flutter/dart/pre-commit in the new tree:
cd /home/otaj/.cursor/worktrees/zelp/<name>
./scripts/setup_worktree.sh           # fvm use + pub get via run_fvm.sh
```

Then move the agent root to that directory.

### Do not

- Call bare `fvm` / `flutter` / `dart` from hooks or agent shells that may have
  `GIT_DIR` set — use `./scripts/run_fvm.sh …`.
- Run hooks/tests in a worktree until `.fvm/` exists (`test -e .fvm/flutter_sdk`)
  and `./scripts/setup_worktree.sh` has succeeded.
- Interrupt `fvm install` / auto-repair, or run two installs of the same version
  at once.
- Delete or “fix” `~/fvm/versions/<ver>` while other sessions may use it.
- `cd` into `.fvm/flutter_sdk` and run `git` — that is the shared SDK clone.

### Repair a corrupted shared SDK

Only if `~/fvm/versions/$(jq -r .flutter .fvmrc)/bin/flutter` is missing or not
executable, or `./scripts/run_fvm.sh flutter --version` does not show the pin:

```bash
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR
rm -f "${FVM_CACHE_PATH:-$HOME/fvm}/cache.git.lock"
./scripts/run_fvm.sh install "$(jq -r .flutter .fvmrc)"   # one process only
# then in each affected worktree:
./scripts/setup_worktree.sh
```

### Why format/tests fail in a raw worktree

Without `setup_worktree.sh`, there is no `.dart_tool/` either. `dart format`
cannot resolve `analysis_options.yaml` (`include: package:lints/...`) and falls
back to the default 80-column width, rewriting the tree. That is a symptom of
skipping setup, not a separate formatter bug.

## Commits: dependency updates alone

Dependency changes (`pubspec.yaml` / `pubspec.lock`, adding or upgrading a
package) must be their **own commit**, never mixed into feature/fix/refactor
commits. If a change needs a new dependency, commit `chore(deps): …` first, then
the code that uses it.
