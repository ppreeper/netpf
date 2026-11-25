#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
. "$REPO_ROOT/build/build.conf"

BUILD_PATH="$REPO_ROOT/$BUILD_DIR"
OUTPUT_PATH="$REPO_ROOT/$OUTPUT_DIR"
PACKAGE_FILE="$REPO_ROOT/$PACKAGE_LIST"
POUDRIERE_CONF=/usr/local/etc/poudriere.conf
RELEASE_URL="https://download.freebsd.org/releases/$FREEBSD_ARCH/$FREEBSD_RELEASE"

fail() {
	printf 'netpf-build: ERROR: %s\n' "$*" >&2
	exit 1
}

info() {
	printf 'netpf-build: %s\n' "$*"
}

validate_config() {
	case "$FREEBSD_RELEASE" in
		*-RELEASE) ;;
		*) fail "FREEBSD_RELEASE must be a pinned FreeBSD release (got '$FREEBSD_RELEASE')" ;;
	esac
	[ "$FREEBSD_ARCH" = amd64 ] || fail "the initial image target is amd64 (got '$FREEBSD_ARCH')"
	case "$PORTS_BRANCH" in
		[0-9][0-9][0-9][0-9]Q[1-4]) ;;
		*) fail "PORTS_BRANCH must be a quarterly branch such as 2026Q3 (got '$PORTS_BRANCH')" ;;
	esac
	case "$IMAGE_SIZE" in
		[1-9][0-9]*G) ;;
		*) fail "IMAGE_SIZE must be a size in gigabytes, for example 12G (got '$IMAGE_SIZE')" ;;
	esac
	case "$IMAGE_NAME" in
		*[!A-Za-z0-9._-]*) fail "IMAGE_NAME may contain only letters, digits, dots, underscores, and hyphens" ;;
	esac
	[ -f "$PACKAGE_FILE" ] || fail "package list not found: $PACKAGE_FILE"
	awk '
		{
			line = $0
			sub(/[[:space:]]*#.*/, "", line)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
			if (line == "") next
			$0 = line
			if (NF != 2 || $1 !~ /^[A-Za-z0-9_.+-]+$/ || $2 !~ /^[A-Za-z0-9_.+-]+\/[A-Za-z0-9_.+-]+$/) exit 1
		}
		{ count++ }
		END { if (count == 0) exit 1 }
	' "$PACKAGE_FILE" || fail "package list must contain at least one valid package name: $PACKAGE_FILE"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

check_host() {
	[ "$(uname -s)" = FreeBSD ] || fail "image creation requires a FreeBSD host; current host is $(uname -s)"
	[ "$(id -u)" -eq 0 ] || fail "image creation must run as root (use sudo or a root shell)"
	for command in awk cat cp date fetch git gpart id install mdconfig mkdir mount_msdosfs mv newfs_msdos pkg poudriere rm sha256 tar truncate umount uname zfs zpool; do
		require_command "$command"
	done
	[ -r "$POUDRIERE_CONF" ] || fail "missing $POUDRIERE_CONF; prepare it from build/poudriere.conf.sample"
	awk -F= -v expected="$POUDRIERE_ROOT" '
		$1 == "BASEFS" { gsub(/[" '\'' ]/, "", $2); if ($2 == expected) found=1 }
		END { exit !found }
	' "$POUDRIERE_CONF" || fail "set BASEFS=$POUDRIERE_ROOT in $POUDRIERE_CONF"
	BUILD_ZPOOL=$(awk -F= '$1 == "ZPOOL" { gsub(/[" '\'' ]/, "", $2); print $2; exit }' "$POUDRIERE_CONF")
	[ -n "$BUILD_ZPOOL" ] || fail "set ZPOOL to an existing ZFS pool in $POUDRIERE_CONF"
	zpool list -H "$BUILD_ZPOOL" >/dev/null 2>&1 || fail "Poudriere ZPOOL does not exist: $BUILD_ZPOOL"
	info "FreeBSD build host prerequisites are available"
}

normalize_packages() {
	awk '{ sub(/[[:space:]]*#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (length) print $1 }' "$PACKAGE_FILE"
}

normalize_origins() {
	awk '{ sub(/[[:space:]]*#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (length) print $2 }' "$PACKAGE_FILE"
}

normalize_package_specs() {
	awk '{ sub(/[[:space:]]*#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (length) print $1, $2 }' "$PACKAGE_FILE"
}

prepare_distfiles_cache() {
	DISTFILES_CACHE=$(awk -v base="$POUDRIERE_ROOT" '
		{
			line=$0
			sub(/^[[:space:]]+/, "", line)
			if (line !~ /^DISTFILES_CACHE[[:space:]]*=/) next
			sub(/^[^=]*=/, "", line)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
			gsub(/"/, "", line)
			gsub(/\047/, "", line)
			gsub(/\$\{BASEFS\}/, base, line)
			print line
			exit
		}
	' "$POUDRIERE_CONF")
	[ -n "$DISTFILES_CACHE" ] || DISTFILES_CACHE=/usr/ports/distfiles
	case "$DISTFILES_CACHE" in
		/*) mkdir -p "$DISTFILES_CACHE" ;;
		*) fail "DISTFILES_CACHE must resolve to an absolute path (got '$DISTFILES_CACHE')" ;;
	esac
}

jail_exists() {
	poudriere jail -l 2>/dev/null | awk -v wanted="$POUDRIERE_JAIL" '$1 == wanted { found=1 } END { exit !found }'
}

ports_exists() {
	poudriere ports -l 2>/dev/null | awk -v wanted="$POUDRIERE_PORTS" '$1 == wanted { found=1 } END { exit !found }'
}

setup_poudriere() {
	check_host
	prepare_distfiles_cache
	if jail_exists; then
		info "Poudriere jail '$POUDRIERE_JAIL' already exists"
	else
		info "Creating Poudriere jail for $FREEBSD_RELEASE/$FREEBSD_ARCH"
		poudriere jail -c -j "$POUDRIERE_JAIL" -v "$FREEBSD_RELEASE" -a "$FREEBSD_ARCH" -m ftp
	fi
	if ports_exists; then
		info "Poudriere ports tree '$POUDRIERE_PORTS' already exists"
	else
		info "Creating Poudriere ports tree at branch $PORTS_BRANCH"
		poudriere ports -c -p "$POUDRIERE_PORTS" -m git+https -U https://git.FreeBSD.org/ports.git -B "$PORTS_BRANCH"
	fi
}

build_packages() {
	if ! jail_exists || ! ports_exists; then
		fail "Poudriere jail or ports tree is missing; run 'make setup' first"
	fi
	prepare_distfiles_cache
	info "Building declared packages in the isolated Poudriere jail"
	mkdir -p "$BUILD_PATH"
	normalize_origins > "$BUILD_PATH/origins.txt"
	poudriere bulk -j "$POUDRIERE_JAIL" -p "$POUDRIERE_PORTS" -f "$BUILD_PATH/origins.txt"
	POUDRIERE_DATA=${POUDRIERE_DATA:-$POUDRIERE_ROOT/data}
	PACKAGE_REPOSITORY="$POUDRIERE_DATA/packages/$POUDRIERE_JAIL-$POUDRIERE_PORTS"
	[ -d "$PACKAGE_REPOSITORY/All" ] || fail "Poudriere package repository not found: $PACKAGE_REPOSITORY"
	PORTS_COMMIT=$(git -C "$POUDRIERE_ROOT/ports/$POUDRIERE_PORTS" rev-parse HEAD)
}

fetch_release_set() {
	name=$1
	checksum_file="$BUILD_PATH/dist/MANIFEST"
	artifact="$BUILD_PATH/dist/$name"
	if [ ! -f "$checksum_file" ]; then
		fetch -o "$checksum_file" "$RELEASE_URL/MANIFEST"
	fi
	if [ ! -f "$artifact" ]; then
		fetch -o "$artifact" "$RELEASE_URL/$name"
	fi
	expected=$(awk -v file="$name" '$1 == file { print $2; exit }' "$checksum_file")
	[ -n "$expected" ] || fail "no upstream SHA256 entry found for $name"
	actual=$(sha256 -q "$artifact")
	[ "$actual" = "$expected" ] || fail "SHA256 mismatch for $name"
	case "$name" in
		base.txz) BASE_SHA256=$actual ;;
		kernel.txz) KERNEL_SHA256=$actual ;;
	esac
	RELEASE_MANIFEST_SHA256=$(sha256 -q "$checksum_file")
	info "Verified FreeBSD release artifact $name"
}

install_declared_packages() {
	normalize_packages > "$BUILD_PATH/packages.txt"
	set --
	while IFS= read -r package || [ -n "$package" ]; do
		set -- "$@" "$package"
	done < "$BUILD_PATH/packages.txt"
	[ "$#" -gt 0 ] || fail "package list is empty: $PACKAGE_FILE"
	mkdir -p "$BUILD_PATH/pkg-repos"
	cat > "$BUILD_PATH/pkg-repos/NetPF.conf" <<EOF
NetPF: {
  url: "file://$PACKAGE_REPOSITORY",
  mirror_type: "none",
  signature_type: "none",
  enabled: yes
}
EOF
	info "Installing packages exclusively from the local Poudriere repository"
	pkg -r "$ROOT_MOUNT" -o "REPOS_DIR=$BUILD_PATH/pkg-repos" -o "ABI=FreeBSD:15:amd64" install -y -r NetPF "$@"
}

cleanup_image_build() {
	status=$?
	trap - 0 1 2 15
	if [ -n "${EFI_MOUNTED:-}" ]; then
		umount "$EFI_MOUNT" >/dev/null 2>&1 || status=1
	fi
	if [ -n "${POOL_CREATED:-}" ]; then
		zpool export "$POOL_NAME" >/dev/null 2>&1 || status=1
	fi
	if [ -n "${MD_UNIT:-}" ]; then
		mdconfig -d -u "$MD_UNIT" >/dev/null 2>&1 || status=1
	fi
	return "$status"
}

assemble_image() {
	mkdir -p "$BUILD_PATH/dist" "$OUTPUT_PATH"
	fetch_release_set base.txz
	fetch_release_set kernel.txz
	ROOT_MOUNT="$BUILD_PATH/root"
	EFI_MOUNT="$BUILD_PATH/efi"
	IMAGE_TEMP="$BUILD_PATH/$IMAGE_NAME"
	POOL_NAME="netpfbuild$$"
	EFI_LABEL="NP${$}EFI"
	ZFS_LABEL="NP${$}ZFS"
	MD_UNIT=
	POOL_CREATED=
	EFI_MOUNTED=
	trap cleanup_image_build 0
	trap 'exit 1' 1 2 15
	rm -f "$IMAGE_TEMP"
	mkdir -p "$ROOT_MOUNT" "$EFI_MOUNT"
	truncate -s "$IMAGE_SIZE" "$IMAGE_TEMP"
	MD_UNIT=$(mdconfig -a -t vnode -f "$IMAGE_TEMP")
	case "$MD_UNIT" in
		md[0-9]*) ;;
		*) fail "mdconfig returned an unexpected device name: $MD_UNIT" ;;
	esac
	gpart create -s GPT "/dev/$MD_UNIT"
	gpart add -a 1M -s 260M -t efi -l "$EFI_LABEL" "/dev/$MD_UNIT"
	gpart add -a 1M -t freebsd-zfs -l "$ZFS_LABEL" "/dev/$MD_UNIT"
	newfs_msdos -F 32 -c 8 -L NETPF "/dev/gpt/$EFI_LABEL"
	zpool create -f -o "altroot=$ROOT_MOUNT" -o cachefile=none -o ashift=12 \
		-O mountpoint=none -O compression=lz4 -O atime=off "$POOL_NAME" "/dev/gpt/$ZFS_LABEL"
	POOL_CREATED=yes
	zfs create -o mountpoint=none "$POOL_NAME/ROOT"
	zfs create -o mountpoint=/ -o canmount=noauto "$POOL_NAME/ROOT/default"
	zpool set "bootfs=$POOL_NAME/ROOT/default" "$POOL_NAME"
	zfs mount "$POOL_NAME/ROOT/default"
	tar -xpf "$BUILD_PATH/dist/base.txz" -C "$ROOT_MOUNT"
	tar -xpf "$BUILD_PATH/dist/kernel.txz" -C "$ROOT_MOUNT"
	zfs create -o mountpoint=/etc/netpf "$POOL_NAME/config"
	zfs create -o mountpoint=/var/db/netpf "$POOL_NAME/data"
	install_declared_packages
	cat > "$ROOT_MOUNT/boot/loader.conf" <<EOF
zfs_load="YES"
vfs.root.mountfrom="zfs:$POOL_NAME/ROOT/default"
console="comconsole"
EOF
	cat > "$ROOT_MOUNT/etc/rc.conf" <<'EOF'
EOF
	: > "$ROOT_MOUNT/etc/fstab"
	mount_msdosfs "/dev/gpt/$EFI_LABEL" "$EFI_MOUNT"
	EFI_MOUNTED=yes
	mkdir -p "$EFI_MOUNT/EFI/BOOT"
	cp "$ROOT_MOUNT/boot/loader.efi" "$EFI_MOUNT/EFI/BOOT/BOOTX64.EFI"
	cleanup_image_build
	IMAGE_SHA256=$(sha256 -q "$IMAGE_TEMP")
	mv "$IMAGE_TEMP" "$OUTPUT_PATH/$IMAGE_NAME"
	write_manifest "$IMAGE_SHA256" "$POOL_NAME" "$PORTS_COMMIT"
	info "Image ready: $OUTPUT_PATH/$IMAGE_NAME"
}

write_manifest() {
	image_sha=$1
	pool_name=$2
	ports_commit=$3
	manifest="$OUTPUT_PATH/$IMAGE_NAME.manifest.json"
	ports_jail_version=$(poudriere jail -l | awk -v jail="$POUDRIERE_JAIL" '$1 == jail { print $2; exit }')
	[ -n "$ports_jail_version" ] || fail "could not determine Poudriere jail version for $POUDRIERE_JAIL"
	poudriere_version=$(poudriere version | awk 'NR == 1 { print $NF; exit }')
	pkg_config_sha256=$(sha256 -q "$POUDRIERE_CONF")
	build_config_sha256=$(sha256 -q "$REPO_ROOT/build/build.conf")
	package_list_sha256=$(sha256 -q "$PACKAGE_FILE")
	normalize_package_specs > "$BUILD_PATH/package-specs.txt"
	{
		printf '{\n'
		printf '  "image": "%s",\n' "$IMAGE_NAME"
		printf '  "sha256": "%s",\n' "$image_sha"
		printf '  "built_at_utc": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
		printf '  "freebsd_release": "%s",\n' "$FREEBSD_RELEASE"
		printf '  "architecture": "%s",\n' "$FREEBSD_ARCH"
		printf '  "input_sha256": {\n'
		printf '    "release_manifest": "%s",\n' "$RELEASE_MANIFEST_SHA256"
		printf '    "base_txz": "%s",\n' "$BASE_SHA256"
		printf '    "kernel_txz": "%s",\n' "$KERNEL_SHA256"
		printf '    "build_config": "%s",\n' "$build_config_sha256"
		printf '    "package_list": "%s",\n' "$package_list_sha256"
		printf '    "poudriere_config": "%s"\n' "$pkg_config_sha256"
		printf '  },\n'
		printf '  "poudriere": {\n'
		printf '    "version": "%s",\n' "$poudriere_version"
		printf '    "jail": "%s",\n' "$POUDRIERE_JAIL"
		printf '    "jail_version": "%s",\n' "$ports_jail_version"
		printf '    "ports_tree": "%s",\n' "$POUDRIERE_PORTS"
		printf '    "ports_branch": "%s",\n' "$PORTS_BRANCH"
		printf '    "ports_commit": "%s"\n' "$ports_commit"
		printf '  },\n'
		printf '  "image_size": "%s",\n' "$IMAGE_SIZE"
		printf '  "ports_branch": "%s",\n' "$PORTS_BRANCH"
		printf '  "ports_commit": "%s",\n' "$ports_commit"
		printf '  "zfs_root": "%s/ROOT/default",\n' "$pool_name"
		printf '  "packages": ['
		first=yes
		while IFS=' ' read -r package origin || [ -n "$package" ]; do
			version=
			for archive in "$PACKAGE_REPOSITORY/All/$package"-*.pkg; do
				[ -f "$archive" ] || continue
				[ "$(pkg query -F "$archive" '%n')" = "$package" ] || continue
				version=$(pkg query -F "$archive" '%v')
				break
			done
			[ -n "$version" ] || fail "could not determine built package version for $package"
			if [ "$first" = yes ]; then first=no; else printf ', '; fi
			printf '{"name": "%s", "origin": "%s", "version": "%s"}' "$package" "$origin" "$version"
		done < "$BUILD_PATH/package-specs.txt"
		printf ']\n}\n'
	} > "$manifest"
	printf '%s  %s\n' "$image_sha" "$IMAGE_NAME" > "$OUTPUT_PATH/$IMAGE_NAME.sha256"
}

smoke_test() {
	[ "$(uname -s)" = FreeBSD ] || [ "$(uname -s)" = Linux ] || fail "QEMU smoke testing is supported on FreeBSD and Linux hosts"
	image="$OUTPUT_PATH/$IMAGE_NAME"
	[ -f "$image" ] || fail "image not found: $image (run 'make build' first)"
	[ -n "${QEMU_UEFI_FIRMWARE:-}" ] || fail "set QEMU_UEFI_FIRMWARE to an OVMF/UEFI firmware image"
	[ -f "$QEMU_UEFI_FIRMWARE" ] || fail "UEFI firmware image not found: $QEMU_UEFI_FIRMWARE"
	require_command qemu-system-x86_64
	require_command grep
	log="$BUILD_PATH/qemu-serial.log"
	mkdir -p "$BUILD_PATH"
	rm -f "$log"
	info "Booting image in QEMU; waiting up to 300 seconds for the multi-user login prompt"
	qemu-system-x86_64 -machine q35 -m 2048 -smp 2 -bios "$QEMU_UEFI_FIRMWARE" \
		-drive "file=$image,format=raw,if=virtio" -display none -monitor none \
		-serial "file:$log" -no-reboot &
qemu_pid=$!
	trap 'kill "$qemu_pid" >/dev/null 2>&1 || true; wait "$qemu_pid" >/dev/null 2>&1 || true' 0 1 2 15

	count=0
	while [ "$count" -lt 300 ]; do
		if [ -f "$log" ] && grep -q 'login:' "$log"; then
			kill "$qemu_pid" >/dev/null 2>&1 || true
			wait "$qemu_pid" >/dev/null 2>&1 || true
			trap - 0 1 2 15
			grep -E 'Mounting from zfs:|login:' "$log" || true
			info "QEMU reached the multi-user login prompt; serial log: $log"
			return 0
		fi
		if ! kill -0 "$qemu_pid" >/dev/null 2>&1; then
			wait "$qemu_pid" || true
			break
		fi
		sleep 1
		count=$((count + 1))
	done
	kill "$qemu_pid" >/dev/null 2>&1 || true
	wait "$qemu_pid" >/dev/null 2>&1 || true
	[ -f "$log" ] && cat "$log"
	fail "QEMU did not reach the multi-user login prompt; see $log"
}

clean_build() {
	case "$BUILD_PATH" in "$REPO_ROOT"/*) rm -rf "$BUILD_PATH" ;; *) fail "refusing to clean unexpected path: $BUILD_PATH" ;; esac
	info "Removed temporary build state; image outputs in $OUTPUT_PATH were kept"
}

validate_config
action=${1:-help}
case "$action" in
	config)
		info "Build configuration is valid for $FREEBSD_RELEASE/$FREEBSD_ARCH with ports $PORTS_BRANCH"
		;;
	check)
		check_host
		info "Builder host is ready; run 'make smoke' with QEMU and UEFI firmware installed to test boot"
		;;
	setup)
		setup_poudriere
		;;
	build)
		check_host
		build_packages
		assemble_image
		;;
	smoke)
		smoke_test
		;;
	clean)
		clean_build
		;;
	help|-h|--help)
		printf 'Usage: %s {config|check|setup|build|smoke|clean}\n' "$0"
		;;
	*) fail "unknown command '$action'" ;;
esac
