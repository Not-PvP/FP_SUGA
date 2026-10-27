# Contributing to SUGA

Two people work on this repo, so the rules are short.

## Branches

- `main` is always buildable. Nobody commits to it directly.
- One branch per issue, created from an up-to-date `main`:
  `feature/issue-<number>-<short-name>` (for example `feature/issue-16-ui-components`).
  Use `fix/issue-<number>-<short-name>` for bug fixes and `docs/<short-name>` for documentation only.
- Keep a branch small enough to review in one sitting. If an issue is big, split it.

```
git checkout main
git pull
git checkout -b feature/issue-15-ui-states
```

## Commits

- Write the subject in the imperative, under about 70 characters: `Add retry button to Areas screen`.
- Say why in the body when it is not obvious.
- Commit each logical step, not one big commit at the end. Both members should appear in the history.

## Pull requests

1. Push your branch and open a pull request into `main`. Fill in the template and write `Closes #<issue>`.
2. Run `flutter analyze` and `flutter test` first. Both must pass.
3. Ask the other member to review. Do not review or merge your own pull request.
4. The reviewer reads the diff, runs the app if the change is visible, and leaves comments or approves.
5. Address comments with new commits on the same branch, then re-request review.
6. Merge with "Squash and merge" or "Merge commit" (agree on one) and delete the branch.

If two branches change the same file, whoever merges second updates their branch from `main` and
resolves conflicts before merging.

## Review checklist

- [ ] The change does what the issue asks, and nothing unrelated
- [ ] `flutter analyze` and `flutter test` pass
- [ ] New logic has a test, or the description says why not
- [ ] Screens handle loading, empty, error and offline states
- [ ] Colors, spacing and text use `lib/theme/app_theme.dart`; shared widgets come from `lib/widgets/`
- [ ] No secrets, `.env` files, keystores or personal paths committed
- [ ] README or docs updated if setup or behavior changed

## Issues and board

Every piece of work has an issue with acceptance criteria. Move the card to In progress when you start
a branch, and to Done when its pull request is merged.
