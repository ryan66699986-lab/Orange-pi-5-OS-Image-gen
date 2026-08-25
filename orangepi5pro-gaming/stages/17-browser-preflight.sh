say "Official Brave + Firefox ARM64 browser preflight"
BROWSER_INFO="$(docker run --rm --platform linux/arm64 ubuntu:26.04 bash -ceu '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update >/dev/null
  apt-get install -y --no-install-recommends ca-certificates curl gnupg file >/dev/null

  install -d -m0755 /usr/share/keyrings /etc/apt/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d
  curl --retry 3 --retry-delay 2 -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  expected_brave_fingerprints="$(printf "%s\n" \
    DBF1A116C220B8C7164F98230686B78420038257 \
    47D32A74E9A9E013A4B4926C68D513D36A73CD96 \
    B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0 | sort)"
  actual_brave_fingerprints="$(
    gpg --batch --show-keys --with-colons /usr/share/keyrings/brave-browser-archive-keyring.gpg 2>/dev/null |
      awk -F: "\$1 == \"pub\" { primary=1; next } primary && \$1 == \"fpr\" { print toupper(\$10); primary=0 }" |
      sort -u
  )"
  [[ "$actual_brave_fingerprints" == "$expected_brave_fingerprints" ]] || {
    printf "Official Brave APT keyring primary-fingerprint mismatch. Found:\n%s\n" \
      "${actual_brave_fingerprints:-<none>}" >&2
    exit 1
  }
  curl --retry 3 --retry-delay 2 -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources

  curl --retry 3 --retry-delay 2 -fsSLo /etc/apt/keyrings/packages.mozilla.org.asc \
    https://packages.mozilla.org/apt/repo-signing-key.gpg
  gpg --batch --show-keys --with-colons /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null \
    | grep -Fqi "fpr:::::::::35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3:" \
    || { echo "Official Mozilla signing-key fingerprint mismatch" >&2; exit 1; }
  cat > /etc/apt/sources.list.d/mozilla.sources <<EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
  cat > /etc/apt/preferences.d/mozilla <<EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox
Pin: release o=Ubuntu
Pin-Priority: -1
EOF
  apt-get update >/dev/null
  apt-get install -y --no-install-recommends brave-browser firefox >/dev/null
  [[ "$(dpkg --print-architecture)" == arm64 ]]
  command -v brave-browser >/dev/null
  command -v firefox >/dev/null
  [[ "$(dpkg-query -W -f="\${Architecture}" brave-browser)" == arm64 ]]
  [[ "$(dpkg-query -W -f="\${Architecture}" firefox)" == arm64 ]]
  printf "BRAVE_VERSION=%s\n" "$(dpkg-query -W -f="\${Version}" brave-browser)"
  printf "FIREFOX_VERSION=%s\n" "$(dpkg-query -W -f="\${Version}" firefox)"
')"
printf '%s\n' "$BROWSER_INFO"
BRAVE_VERSION="$(sed -n 's/^BRAVE_VERSION=//p' <<<"$BROWSER_INFO")"
FIREFOX_VERSION="$(sed -n 's/^FIREFOX_VERSION=//p' <<<"$BROWSER_INFO")"
[[ -n "$BRAVE_VERSION" && -n "$FIREFOX_VERSION" ]] || die "Browser preflight did not return package versions"
jq --arg brave "$BRAVE_VERSION" --arg firefox "$FIREFOX_VERSION" \
  '.components.brave_browser=$brave | .components.firefox=$firefox' "$LOCK" > "${LOCK}.tmp"
mv "${LOCK}.tmp" "$LOCK"
good "Official Brave ${BRAVE_VERSION} and Firefox ${FIREFOX_VERSION} ARM64 packages install and execute"
