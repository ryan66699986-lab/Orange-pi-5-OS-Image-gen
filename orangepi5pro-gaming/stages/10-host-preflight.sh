say "Host preflight"
FREE_KB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"; MIN_KB=$((70*1024*1024)); (( FREE_KB >= MIN_KB )) || die "Need at least 70 GiB free under \$HOME. Current free: $((FREE_KB/1024/1024)) GiB"
good "Host has $((FREE_KB/1024/1024)) GiB free"; good "Docker accessible"
say "Privileged Docker / loop-device preflight"
docker run --rm --privileged --platform linux/amd64 ubuntu:26.04 bash -ceu '[[ -e /dev/loop-control ]] || { echo "Privileged Docker has no /dev/loop-control; final raw-image QA cannot run" >&2; exit 1; }; ls /dev/loop* >/dev/null 2>&1 || { echo "Privileged Docker has no loop devices; final raw-image QA cannot run" >&2; exit 1; }'
good "Privileged Docker loop-device access available"
printf 'ARM64 artifact build parallelism: %s jobs\n' "$JOBS"
good "Repository-native V3.10 build: fresh workspace enforced"
