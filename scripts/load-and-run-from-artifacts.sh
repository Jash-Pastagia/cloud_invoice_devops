#!/usr/bin/env bash
set -euo pipefail

# load-and-run-from-artifacts.sh
# Usage:
#  ./scripts/load-and-run-from-artifacts.sh ./artifacts
#  ./scripts/load-and-run-from-artifacts.sh auth-service.tar
#
# Loads docker image tar artifacts, tags them to the expected GHCR names, and
# runs docker compose using the loaded images (no build).

echo "\nStarting stack with docker compose (no build)"
ARTIFACT_PATH=${1:-./}
OWNER="jash-pastagia"
REPO="cloud-invoice"

echo "Loading images from: $ARTIFACT_PATH"

# Helper: get first RepoTags from manifest.json inside the tar
function repotags_from_tar() {
  local tarfile="$1"
  # manifest.json is present in docker save archives; extract RepoTags array
  if tar -tf "$tarfile" | grep -q "manifest.json"; then
    # extract manifest.json and parse RepoTags
    tags=$(tar -xOf "$tarfile" manifest.json 2>/dev/null | python3 -c "import sys, json
import sys
man=json.load(sys.stdin)
if len(man)>0 and 'RepoTags' in man[0] and man[0]['RepoTags']:
    print('\n'.join(man[0]['RepoTags']))
")
    echo "$tags"
    return 0
  fi
  # older format may have repositories file
  if tar -tf "$tarfile" | grep -q "repositories"; then
    tar -xOf "$tarfile" repositories 2>/dev/null | python3 -c "import sys, json
repos=json.load(sys.stdin)
out=[]
for r, tags in repos.items():
    for t in tags.keys():
        out.append(f'{r}:{t}')
print('\n'.join(out))
" || true
  return 1
}

# Iterate over provided files or directory
if [ -d "$ARTIFACT_PATH" ]; then
  files=("$ARTIFACT_PATH"/*.tar)
else
  files=("$ARTIFACT_PATH")
fi

loaded_images=()

for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then
    echo "No tar files found at $f - skipping"
    continue
  fi
  echo "\n--- Processing $f ---"

  # Try to read RepoTags from tar before loading
  repo_tags=$(repotags_from_tar "$f" 2>/dev/null || true)
  if [ -n "$repo_tags" ]; then
    echo "Found RepoTags in tar:"
    echo "$repo_tags"
  else
    echo "No RepoTags found in tar; docker load output will be used as fallback"
  fi

  # Load the tar
  out=$(docker load -i "$f" 2>&1 || true)
  echo "$out"

  # parse docker load output for Loaded image lines
  loaded_names=$(echo "$out" | grep -Eo "Loaded image: .*" | sed 's/Loaded image: //')

  # If we have repo_tags from manifest use them; else fall back to docker load names
  if [ -n "$repo_tags" ]; then
    while IFS= read -r tag; do
      # retag to ghcr path
      svc=$(echo "$tag" | awk -F'/' '{print $NF}' | awk -F':' '{print $1}')
      sha_tag=$(echo "$tag" | awk -F':' '{print $NF}')
      target="ghcr.io/${OWNER}/${REPO}/${svc}:${sha_tag}"
      echo "Tagging $tag -> $target"
      docker tag "$tag" "$target" || true
      loaded_images+=("$target")
    done <<<"$repo_tags"
  elif [ -n "$loaded_names" ]; then
    while IFS= read -r name; do
      # name may be repo:tag or sha256:...
      if [[ "$name" == sha256:* ]]; then
        echo "Loaded image is sha digest ($name); listing recent images to find ID"
        imgid=$(docker images --no-trunc --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "<none>" -v | head -n 1 | awk '{print $2}') || true
        if [ -n "$imgid" ]; then
          echo "Found image id $imgid; will skip automatic retag. Please tag manually if needed."
        fi
      else
        svc=$(echo "$name" | awk -F'/' '{print $NF}' | awk -F':' '{print $1}')
        sha_tag=$(echo "$name" | awk -F':' '{print $NF}')
        target="ghcr.io/${OWNER}/${REPO}/${svc}:${sha_tag}"
        echo "Tagging $name -> $target"
        docker tag "$name" "$target" || true
        loaded_images+=("$target")
      fi
    done <<<"$loaded_names"
  else
    # Ultimate fallback: pick most recent image and tag by filename
    recent=$(docker images --format "{{.Repository}}:{{.Tag}} {{.CreatedAt}}" | head -n 1 | awk '{print $1}') || true
    svcname=$(basename "$f" .tar)
    target="ghcr.io/${OWNER}/${REPO}/${svcname}:latest"
    if [ -n "$recent" ]; then
      echo "Tagging recent image $recent -> $target"
      docker tag "$recent" "$target" || true
      loaded_images+=("$target")
    else
      echo "Could not determine any image to tag for $f"
    fi
  fi

done

if [ ${#loaded_images[@]} -eq 0 ]; then
  echo "No images loaded/tagged. Exiting."
  exit 1
fi

echo "\nLoaded and tagged images:"
for img in "${loaded_images[@]}"; do
  echo " - $img"
done

# Run docker compose using loaded images
echo "\nStarting stack with docker compose (no build)"
docker compose up --no-build -d

echo "\nStack started. Use 'docker compose ps' to check services."
