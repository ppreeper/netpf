#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
. "$REPO_ROOT/build/build.conf"

INCUS_INSTANCE=${INCUS_INSTANCE:-netpf-build-host}
INCUS_IMAGE=${INCUS_IMAGE:-images:freebsd/15.0}
INCUS_CPUS=${INCUS_CPUS:-4}
INCUS_MEMORY=${INCUS_MEMORY:-6GiB}
INCUS_DISK=${INCUS_DISK:-80GiB}
GUEST_REPO=/root/netpf

fail() {
	printf 'netpf-incus: ERROR: %s\n' "$*" >&2
	exit 1
}

info() {
	printf 'netpf-incus: %s\n' "$*"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

instance_exists() {
	incus info "$INCUS_INSTANCE" >/dev/null 2>&1
}

ensure_instance() {
	require_command incus
	if instance_exists; then
		info "Reusing Incus instance '$INCUS_INSTANCE'"
	else
		info "Creating FreeBSD build VM '$INCUS_INSTANCE' from $INCUS_IMAGE"
		incus launch "$INCUS_IMAGE" "$INCUS_INSTANCE" --vm \
			-c limits.cpu="$INCUS_CPUS" \
			-c limits.memory="$INCUS_MEMORY" \
			-c security.secureboot=false \
			-d "root,size=$INCUS_DISK"
	fi
	state=$(incus info "$INCUS_INSTANCE" | awk -F: '/^Status:/ { gsub(/[[:space:]]/, "", $2); print toupper($2); exit }')
	if [ "$state" != RUNNING ]; then
		incus start "$INCUS_INSTANCE"
	fi
	count=0
	while [ "$count" -lt 180 ]; do
		if incus exec "$INCUS_INSTANCE" -- true >/dev/null 2>&1; then
			break
		fi
		sleep 2
		count=$((count + 1))
	done
	[ "$count" -lt 180 ] || fail "Incus guest agent did not become ready in '$INCUS_INSTANCE'"
	incus exec "$INCUS_INSTANCE" -- sh -c '
		[ "$(uname -s)" = FreeBSD ] || exit 10
		case "$(uname -m)" in amd64|x86_64) ;; *) exit 11 ;; esac
		case "$(freebsd-version -u)" in 15.0-RELEASE*) ;; *) exit 12 ;; esac
		zpool list zroot >/dev/null 2>&1 || exit 13
	' || fail "instance must be FreeBSD 15.0 amd64 with a zroot pool"
}

prepare_guest() {
	ensure_instance
	info "Ensuring pkg, Poudriere, and Git are installed in the guest"
	incus exec "$INCUS_INSTANCE" --env ASSUME_ALWAYS_YES=yes -- pkg bootstrap -y
	incus exec "$INCUS_INSTANCE" -- pkg install -y poudriere git
	if incus exec "$INCUS_INSTANCE" -- test -e /usr/local/etc/poudriere.conf; then
		incus exec "$INCUS_INSTANCE" -- sh -c '
			conf=/usr/local/etc/poudriere.conf
			basefs=$(awk -F= '\''$1 == "BASEFS" { gsub(/["[:space:]]/, "", $2); print $2; exit }'\'' "$conf")
			zpool=$(awk -F= '\''$1 == "ZPOOL" { gsub(/["[:space:]]/, "", $2); print $2; exit }'\'' "$conf")
			[ "$basefs" = "$1" ] || exit 10
			case "$zpool" in
				"") printf "\\nZPOOL=zroot\\n" >> "$conf" ;;
				zroot) ;;
				*) exit 11 ;;
			esac
		' sh "$POUDRIERE_ROOT" || fail "existing Poudriere config must use BASEFS=$POUDRIERE_ROOT and ZPOOL=zroot"
	else
		incus file push --create-dirs "$REPO_ROOT/build/poudriere.conf.sample" \
			"$INCUS_INSTANCE/usr/local/etc/poudriere.conf"
	fi
	incus exec "$INCUS_INSTANCE" -- mkdir -p "$GUEST_REPO/build" "$GUEST_REPO/scripts" "$GUEST_REPO/out"
	incus file push --create-dirs "$REPO_ROOT/build/build.conf" \
		"$INCUS_INSTANCE$GUEST_REPO/build/build.conf"
	incus file push --create-dirs "$REPO_ROOT/build/packages.txt" \
		"$INCUS_INSTANCE$GUEST_REPO/build/packages.txt"
	incus file push --create-dirs "$REPO_ROOT/scripts/build-image.sh" \
		"$INCUS_INSTANCE$GUEST_REPO/scripts/build-image.sh"
	incus exec "$INCUS_INSTANCE" -- sh -c 'chmod 755 /root/netpf/scripts/build-image.sh'
}

pull_outputs() {
	image="$OUTPUT_DIR/$IMAGE_NAME"
	mkdir -p "$REPO_ROOT/$OUTPUT_DIR"
	for artifact in "$IMAGE_NAME" "$IMAGE_NAME.sha256" "$IMAGE_NAME.manifest.json"; do
		incus file pull "$INCUS_INSTANCE$GUEST_REPO/$OUTPUT_DIR/$artifact" "$REPO_ROOT/$OUTPUT_DIR/$artifact"
	done
	info "Image and provenance files copied to $REPO_ROOT/$image"
}

run_build() {
	prepare_guest
	info "Preparing the Poudriere jail and ports tree"
	incus exec "$INCUS_INSTANCE" --cwd "$GUEST_REPO" -- sh scripts/build-image.sh setup
	info "Building the FreeBSD/ZFS image inside the Incus VM"
	incus exec "$INCUS_INSTANCE" --cwd "$GUEST_REPO" -- sh scripts/build-image.sh build
	pull_outputs
}

case "${1:-help}" in
	config)
		printf 'Incus image: %s\nInstance: %s\nFreeBSD: %s/%s\n' \
			"$INCUS_IMAGE" "$INCUS_INSTANCE" "$FREEBSD_RELEASE" "$FREEBSD_ARCH"
		;;
	setup)
		prepare_guest
		incus exec "$INCUS_INSTANCE" --cwd "$GUEST_REPO" -- sh scripts/build-image.sh setup
		info "Incus FreeBSD build host is ready"
		;;
	build)
		run_build
		;;
	*)
		printf 'Usage: %s {config|setup|build}\n' "$0"
		[ "${1:-help}" = help ] || fail "unknown command '${1:-}'"
		;;
esac
