# Pre-commit checks

Run `git config --worktree core.hooksPath .githooks` to enable the hook in the current checkout. Linked worktrees require `extensions.worktreeConfig` to be enabled.

The hook checks all staged changes with `git diff --cached --check`. When Swift sources, build configuration, test scripts, or the hook itself change, it exports the index to a temporary directory and runs `scripts/test.sh` and `scripts/ticket03_test.sh` there. SwiftPM compiles the staged sources, and unstaged edits stay in the working tree.

The test step requires the macOS Swift toolchain and Python 3. Desktop acceptance tests can be run separately with their scripts in `scripts/`.
