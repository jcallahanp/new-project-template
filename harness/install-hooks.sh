#!/usr/bin/env bash
# Install the repo's git hooks. Idempotent. Symlinks harness/hooks/pre-push into the repo's hooks dir,
# so later edits to harness/hooks/pre-push take effect without reinstalling. An existing, different
# pre-push hook is kept as pre-push.bak.<timestamp> rather than overwritten.
set -euo pipefail
top=$(git rev-parse --show-toplevel)
cd "$top"
hooks_dir=$(git rev-parse --git-path hooks)
mkdir -p "$hooks_dir"
src="$top/harness/hooks/pre-push"
dst="$hooks_dir/pre-push"
chmod +x "$src"
if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
  echo "pre-push hook already installed -> $src"
  exit 0
fi
if [[ -e "$dst" || -L "$dst" ]]; then
  bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
  mv "$dst" "$bak"
  echo "existing pre-push hook moved to $bak"
fi
ln -s "$src" "$dst"
echo "installed pre-push hook: $dst -> $src"
