#!/bin/bash
set -euo pipefail
. /etc/os-release

# Disable ALL repos first
subscription-manager repos --disable="*" || true

# Packages you want to update
PACKAGES=(
  'kernel*'
  'sssd*'
  'atop'
  'htop'
  'xz'
  'ipa*'
)

# Update OS

case "$PLATFORM_ID" in
  *:el10*)
      echo "el10"
      subscription-manager repos --enable=REPO1
      subscription-manager repos --enable=REPO2
      yum update "${PACKAGES[@]}" || true
      ;;
      ;;
  *:el9*)
      echo "el9"
      subscription-manager repos --enable=REPO1
      subscription-manager repos --enable=REPO2
      yum update "${PACKAGES[@]}" || true
      ;;
  *:el8*)
      echo "el8"
      subscription-manager repos --enable=REPO1
      subscription-manager repos --enable=REPO2
      yum reinstall "${PACKAGES[@]}" || true
      ;;
  *)
      echo "unknown: $PLATFORM_ID" >&2
      exit 2
      ;;
esac
