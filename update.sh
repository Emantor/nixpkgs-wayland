#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -euo pipefail
set -x

cd pkgs
./update.sh
echo "internal update status = $?"
cd "${DIR}"

unset NIX_PATH
pkgentries=(); nixpkgentries=();
cache="nixpkgs-wayland"
cprefix="auto-update(${JOB_ID:-"manual"}):"

nixargs=(--experimental-features 'nix-command flakes')
buildargs=(
  --option 'extra-binary-caches' 'https://cache.nixos.org https://nixpkgs-wayland.cachix.org'
  --option 'trusted-public-keys' 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA='
  --option 'build-cores' '0'
  --option 'narinfo-cache-negative-ttl' '0'
)

function readme_entry() {
  t="$(mktemp)"; trap "rm ${t}" EXIT;
  m="$(mktemp)"; trap "rm ${m}" EXIT;
  pkg="${1}"
  metadata="${pkg}/metadata.nix"
  pkgname="$(basename "${pkg}")"
  if [[ ! -f "${pkg}/metadata.nix" ]]; then return; fi
  nix "${nixargs[@]}" eval -f "${metadata}" --json > "${t}" 2>/dev/null
  upattr="$(cat "${t}" | jq -r .upattr)";
  if [[ "${upattr}" == "null" ]]; then upattr="${pkgname}"; fi
  nix "${nixargs[@]}" eval --json ".#${upattr}.meta" > "${m}" 2>/dev/null
  desc="$(cat "${m}" | jq -r .description)"
  home="$(cat "${m}" | jq -r .homepage)"
  pkgentries=("${pkgentries[@]}" "| [${pkgname}](${home}) | ${desc} |");
}

function update_readme() {
  replace="$(printf "%s\n%s\n%s" "<!--pkgs-->" "| Package | Description |" "| --- | --- |")"
  for p in "${pkgentries[@]}"; do
    replace="$(printf "%s\n%s\n" "${replace}" "${p}")"
  done
  replace="$(printf "%s\n<!--pkgs-->" "${replace}")"
  rg --multiline '(?s)(.*)<!--pkgs-->(.*)<!--pkgs-->(.*)' "README.md" --replace "\$1${replace}\$3" > README2.md
  mv README2.md README.md
}

pkgslist=()
for p in `ls -v -d -- ./pkgs/*/ | sort -V`; do
  readme_entry "${p}"
done
update_readme
git commit README.md -m "${cprefix} README.md" || true

# build it!
set -x
out="$(mktemp -d)"
nix-build-uncached -build-flags "$(printf '\"%s\" ' "${buildargs[@]}" "${nixargs[@]}" "--out-link" "${out}/result")" packages.nix

# cache it!
if find ${out} | grep result; then
  nix "${nixargs[@]}" path-info --json -r ${out}/result* > ${out}/path-info.json
  jq -r 'map(select(.ca == null and .signatures == null)) | map(.path) | .[]' < "${out}/path-info.json" > "${out}/paths"
  cachix push "${cache}" < "${out}/paths"
fi

# push it!
if [[ "${JOB_ID:-""}" != "" ]]; then
  echo "we're building on sr.ht, pushing..."
  ssh-keyscan github.com >> ${HOME}/.ssh/known_hosts
  git push origin HEAD
fi
