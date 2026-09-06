#!/usr/bin/env bash
# Pull benbrastmckie/nvim updates into your customized branch.
#
#   master  - pristine mirror of upstream. Never commit here.
#   local   - your branch. Everything you change lives here.
#
# lazy-lock.json is set to always keep your version (see .git/info/attributes).

set -euo pipefail
cd "$(dirname "$0")"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit or stash first:"
  git status --short
  exit 1
fi

echo "==> Fetching upstream"
git fetch upstream

if git merge-base --is-ancestor upstream/master master; then
  echo "==> Already up to date with upstream."
  exit 0
fi

echo
echo "==> New upstream commits:"
git log --oneline --no-decorate master..upstream/master
echo
echo "==> Files changed:"
git diff --stat master..upstream/master
echo

read -r -p "Merge these into your 'local' branch? [y/N] " reply
[[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted. Nothing changed."; exit 0; }

git checkout master
git merge --ff-only upstream/master
git checkout local

if git merge master -m "Merge upstream into local"; then
  echo
  echo "==> Merged cleanly."
  read -r -p "Push master + local to your fork (origin)? [y/N] " push_reply
  [[ "$push_reply" =~ ^[Yy]$ ]] && git push origin master local
  echo "==> Now run:  nvim  then  :Lazy sync  and  :checkhealth"
else
  echo
  echo "==> Conflicts. Resolve them, then:  git add <files> && git commit"
  echo "    To bail out entirely:          git merge --abort"
  exit 1
fi
