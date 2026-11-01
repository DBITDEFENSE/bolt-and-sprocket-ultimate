#!/usr/bin/env sh
# UPDATE 09 section 2c (T-139): build the browser version and put it on Vercel (a static site + the password gate).
#   tools/deploy_web.sh [--no-build] [--preview]
# Needs, once per machine: `npx vercel login` (and, once per project, the password: `npx vercel env add CZ_PASSWORD
# production` in build/web after the first deploy links it; without CZ_PASSWORD the site is open).
# build/web is self-contained (index.html, cz-<hash>.wasm/.js, cz-main-<hash>.pck, packs/, vercel.json,
# middleware.js), so it can also be uploaded through the Vercel API / dashboard instead of the CLI.
cd "$(dirname "$0")/.."
BUILD=1
PROD="--prod"
for a in "$@"; do
	case "$a" in
		--no-build) BUILD=0 ;;
		--preview) PROD="" ;;
	esac
done
if [ "$BUILD" = "1" ]; then
	sh tools/build_web.sh || exit 1
fi
[ -f build/web/index.html ] && [ -f build/web/vercel.json ] && [ -f build/web/middleware.js ] || { echo "[deploy_web] build/web is incomplete"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "[deploy_web] npx (Node.js) is needed"; exit 1; }
# --archive=tgz: thousands of small files are not an issue here, but the packs are big; one archive uploads faster
npx --yes vercel deploy $PROD --yes --archive=tgz --cwd build/web || {
	echo "[deploy_web] the deploy failed: run 'npx vercel login' once, then try again"; exit 1; }
