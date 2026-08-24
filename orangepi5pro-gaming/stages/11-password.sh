say "Initial Pi account password"
printf "Choose the initial password for '%s'. It is hashed immediately and is not logged.\n" "$USER_NAME"
read -rsp "Password: " PI_PASS </dev/tty; printf '\n'; read -rsp "Repeat: " PI_PASS2 </dev/tty; printf '\n'
[[ -n "$PI_PASS" ]] || die "Password may not be empty."
[[ "$PI_PASS" == "$PI_PASS2" ]] || die "Passwords did not match."
PI_PASS_HASH="$(printf '%s' "$PI_PASS" | openssl passwd -6 -stdin)"
unset PI_PASS PI_PASS2
