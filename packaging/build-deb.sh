#!/usr/bin/bash
# Builds dist/cfdns-updater_<version>_all.deb from the repo contents.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
PKG=cfdns-updater
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
chmod 755 "$BUILD"

install -Dm755 "$ROOT/cfdns-updater" "$BUILD/opt/cfdns-updater/cfdns-updater"
install -Dm644 "$ROOT/dns-updater.service" "$BUILD/usr/lib/systemd/system/dns-updater.service"
install -Dm644 "$ROOT/cfdns-updater.env-example" "$BUILD/usr/share/doc/$PKG/cfdns-updater.env-example"
install -Dm644 "$ROOT/README.md" "$BUILD/usr/share/doc/$PKG/README.md"
install -Dm644 "$ROOT/LICENSE.txt" "$BUILD/usr/share/doc/$PKG/copyright"

install -d "$BUILD/DEBIAN"
sed "s/@VERSION@/$VERSION/" "$ROOT/packaging/debian/control" > "$BUILD/DEBIAN/control"
echo "Installed-Size: $(du -sk --exclude=DEBIAN "$BUILD" | cut -f1)" >> "$BUILD/DEBIAN/control"
for script in postinst prerm postrm; do
    install -m755 "$ROOT/packaging/debian/$script" "$BUILD/DEBIAN/$script"
done

mkdir -p "$ROOT/dist"
dpkg-deb --root-owner-group --build "$BUILD" "$ROOT/dist/${PKG}_${VERSION}_all.deb"
