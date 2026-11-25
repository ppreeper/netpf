# Building the first NetPF image

The first build target is a development-quality FreeBSD `15.0-RELEASE` `amd64` raw disk image. It boots through UEFI, uses ZFS for `/`, and keeps `/etc/netpf` and `/var/db/netpf` in separate datasets. Poudriere builds the declared ports packages; FreeBSD release sets provide the base system and kernel.

## Build host

The image assembly uses FreeBSD-native tools. On Linux, the supported development path is an Incus FreeBSD virtual machine; alternatively, use a dedicated FreeBSD `amd64` host as root. The Poudriere pool is build-host storage only. The generated image has its own ZFS pool and is not imported into the host.

### Incus on Linux

The Incus `images` remote publishes a FreeBSD 15.0 `amd64` VM image with ZFS and the Incus guest agent. Install and initialize Incus, then from the repository root run:

```sh
make test
make incus-setup
make incus-build
```

The setup target creates (or reuses) the `netpf-build-host` VM from `images:freebsd/15.0`, disables Secure Boot for the published image, and provisions Poudriere and Git. The default VM has 4 CPUs, 6 GiB RAM, and an 80 GiB root disk. Override `INCUS_INSTANCE`, `INCUS_IMAGE`, `INCUS_CPUS`, `INCUS_MEMORY`, or `INCUS_DISK` in the environment to customize it. The VM and its Poudriere state are persistent so subsequent builds reuse the jail and ports checkout. The build target stages the current package list and scripts, builds inside FreeBSD, and copies the raw image and provenance files into the local `out/` directory. It does not delete or stop the VM.

### Native FreeBSD host

Run the builder as root on FreeBSD `amd64`. The host needs a ZFS pool with sufficient free space for a Poudriere jail, ports tree, and package build.

1. Install the `poudriere` package.
2. Copy `build/poudriere.conf.sample` to `/usr/local/etc/poudriere.conf`.
3. Set `ZPOOL` to an existing host pool and ensure `BASEFS` matches `/usr/local/poudriere`.
4. Ensure the configured pool has enough space for the FreeBSD jail and ports/package data.

Then run `sudo make setup` followed by `sudo make build`. The portable `make test` target also runs on other hosts.

## Build

For a native FreeBSD build, from the repository root:

```sh
make test
sudo make setup
sudo make build
```

`make setup` creates the configured Poudriere jail from the pinned FreeBSD release and checks out the configured quarterly ports branch. It is safe to rerun when both resources already exist. `make build` builds `build/packages.txt` in that jail, verifies the FreeBSD release-set checksums, and assembles the raw image. `make smoke` boots the local `out/` image under QEMU and requires the guest to reach a serial login prompt. To run the smoke test, install `qemu-system-x86_64` and a UEFI firmware image (OVMF), then set `QEMU_UEFI_FIRMWARE` to that firmware file; firmware paths vary by host. `make all` runs a native build and smoke test sequentially.

The build is staged as:

1. Poudriere builds the declared FreeBSD ports origins in an isolated jail; each package-list entry names both the output package and its ports origin.
2. The build downloads and verifies FreeBSD `base.txz` and `kernel.txz` against their SHA-256 entries in the release `MANIFEST`.
3. Image assembly creates a GPT EFI System Partition and ZFS partition, extracts the base/kernel sets, installs packages only from the local Poudriere repository, and configures the ZFS-root boot environment.
4. The output directory receives the raw image, a SHA-256 checksum file, and a JSON provenance manifest. Temporary downloads, package-repository config, and QEMU logs are under `.build/`.

The image's initial layout is:

| Resource | Purpose |
| --- | --- |
| GPT EFI System Partition | UEFI loader at `EFI/BOOT/BOOTX64.EFI` |
| `netpfbuild*/ROOT/default` | Replaceable booted FreeBSD OS environment and ZFS root |
| `netpfbuild*/config` mounted at `/etc/netpf` | Persistent NetPF configuration |
| `netpfbuild*/data` mounted at `/var/db/netpf` | Persistent operational data |

The pool name includes a build-specific suffix to avoid colliding with a pool on the build host. The manifest records the resolved ports commit and Poudriere/jail versions, package names/origins/versions, hashes of the FreeBSD release manifest and base/kernel sets, and hashes of the build, package-list, and Poudriere configuration inputs. The image uses FreeBSD release artifacts; it does not compile FreeBSD world/kernel from source in this initial build.

## Commands and outputs

- `make check` validates native FreeBSD builder prerequisites.
- `make test` checks shell syntax and the checked-in build configuration without requiring FreeBSD.
- `make incus-setup` provisions the Incus FreeBSD build VM and its Poudriere jail/ports tree.
- `make incus-build` builds in that VM and copies results to the local output directory.
- `make clean` removes temporary `.build/` state and preserves completed images.
- Build artifacts are written to `out/`; both output and temporary state are ignored by Git.

See [the base-system PRD](prd/0001-poudriere-zfs-base-system.md) for acceptance criteria and [the architecture baseline](architecture.md) for the larger system direction.
