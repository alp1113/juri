#!/usr/bin/env bash
# Publishes the web build to a static host.
#
#   tools/deploy_web.sh <git-remote-url> [repo-name]
#
# Builds with the base href GitHub Pages needs (a project site is served from
# /<repo>/, not from the root) and force-pushes only build/web to gh-pages.
# The app source never leaves this machine — only the compiled site goes up.
set -euo pipefail

REMOTE="${1:?usage: deploy_web.sh <git-remote-url> [repo-name]}"
REPO="${2:-$(basename "$REMOTE" .git)}"

STAMP="$(date -u +%Y-%m-%d\ %H:%M)"
echo "==> building for /$REPO/  (stamp: $STAMP)"
# The stamp shows at the bottom of the profile tab. A tester reporting a bug
# can read it out, which beats guessing whether they reloaded since the fix.
# PILOT_MODE lowers the community-score thresholds so ten friends can
# actually reach a published score. Drop this flag and the site is back to
# production rules; no source change, nothing to remember.
flutter build web --release --base-href "/$REPO/" \
  --dart-define=BUILD_STAMP="$STAMP" \
  --dart-define=PILOT_MODE=true

# GitHub Pages runs Jekyll by default, which silently drops files and folders
# beginning with an underscore. Flutter does not emit any today, but one new
# dependency that does would break the site with no error anywhere.
touch build/web/.nojekyll

echo "==> publishing"
cd build/web
rm -rf .git
git init -q
git checkout -q -B gh-pages
git add -A
git -c user.email=noreply@juri.app -c user.name=juri commit -qm "Deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push -q --force "$REMOTE" gh-pages
echo "==> done. Enable Pages on the gh-pages branch, then share:"
echo "    https://<your-github-username>.github.io/$REPO/"
