#!/bin/sh
# Regression test for https://github.com/henrygd/beszel/issues/2519
#
# The agent's systemd unit hardens the service with ProtectSystem=strict,
# which mounts the whole filesystem read-only — including /var/tmp, where
# libzypp (zypper) writes temporary files even for read-only commands such
# as `list-updates`. PrivateTmp=yes gives the service private, writable
# /tmp and /var/tmp so package-update checks work on openSUSE without
# loosening the rest of the sandbox.
#
# The unit exists in two places that must stay in sync: the Debian package
# file and the heredoc the install script writes to /etc/systemd/system/.
# This test fails if PrivateTmp=yes is missing from either, or if the two
# hardening blocks drift apart.

set -eu

cd "$(dirname "$0")"

UNIT=../debian/beszel-agent.service
INSTALLER=install-agent.sh

fail() { echo "FAIL: $*" >&2; exit 1; }

# Print the "# Security/sandboxing settings" block (the comment line through
# the following blank line) for the file named in $1.
sandbox_block() {
    sed -n '/# Security\/sandboxing settings/,/^$/p' "$1"
}

block_unit=$(sandbox_block "$UNIT")
block_installer=$(sandbox_block "$INSTALLER")

[ -n "$block_unit" ] || fail "no sandboxing block found in $UNIT"
[ -n "$block_installer" ] || fail "no sandboxing block found in $INSTALLER"

for directive in ProtectSystem=strict PrivateTmp=yes; do
    echo "$block_unit" | grep -qx "$directive" \
        || fail "$UNIT is missing $directive"
    echo "$block_installer" | grep -qx "$directive" \
        || fail "$INSTALLER embedded unit is missing $directive"
done

[ "$block_unit" = "$block_installer" ] \
    || fail "sandboxing block differs between $UNIT and $INSTALLER"

echo "PASS: PrivateTmp=yes present in both unit definitions; sandboxing blocks identical"
