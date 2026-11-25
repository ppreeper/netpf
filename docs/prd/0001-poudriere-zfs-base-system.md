# PRD: Poudriere-built ZFS base system

**Status:** Proposed
**Related decisions:** [FreeBSD base OS](../adr/0006-freebsd-as-the-base-operating-system.md), [Poudriere-built images](../adr/0004-firmware-built-with-poudriere.md), [ZFS storage](../adr/0003-zfs-for-system-and-persistent-state.md)

## Problem Statement

NetPF has an architecture direction but no buildable operating-system foundation. There is no repeatable process to produce a bootable FreeBSD system with a ZFS root and a controlled package set. Without this base, later networking and management features have no stable platform to target, and manual image preparation would be difficult to reproduce or validate.

## Solution

Create a documented, repeatable build pipeline for the first NetPF base-system image. Pin the FreeBSD base-system inputs and ports-tree revision, use Poudriere to build the selected ports packages in an isolated build jail, and assemble the FreeBSD base, kernel, and package artifacts into a bootable ZFS-root disk image.

The first deliverable is a development-quality `amd64` image that boots under UEFI in QEMU and reaches the normal multi-user console. It establishes the root-on-ZFS layout and keeps persistent configuration and data in datasets separate from the replaceable OS environment. It does not yet implement NetPF routing, firewall policy, remote management, firmware updates, or a physical-device installer.

Poudriere builds ports/packages; it does not build FreeBSD's base system. The build pipeline must make that boundary explicit and record the source/release and package inputs used for each image.

### Acceptance criteria

- A documented command or small set of commands builds the image from a clean checkout in a supported FreeBSD build environment.
- FreeBSD base/source inputs, ports-tree revision, package manifest, Poudriere options, and image configuration are pinned or recorded; no ambient package repository is silently used to populate the image.
- Poudriere builds the declared package set in an isolated jail and produces a package repository consumed by image assembly.
- The resulting raw `amd64` disk image uses a documented GPT/UEFI boot layout and boots with its root filesystem on ZFS.
- The ZFS layout provides a booted OS environment and separate persistent configuration and data datasets; exact dataset names and mountpoints are documented with the implementation.
- The image boots to a normal multi-user console in the QEMU smoke test, and the test reports a clear failure if it does not.
- Build output includes the image, a SHA-256 checksum, and a machine-readable manifest identifying source revisions, package inputs, and build settings.
- Re-running the build from the same pinned inputs produces a functionally equivalent bootable image. Bit-for-bit identical images are not required in this first iteration.
- Build failures identify the failed stage and preserve enough logs to diagnose Poudriere, base-system, and image-assembly failures.
- A contributor can follow the documentation to prepare the build host, run the build, boot the image, and understand the resulting ZFS layout.

## User Stories

1. As a NetPF developer, I want one documented build entry point, so that I can create the base image without manually assembling system files.
2. As a NetPF developer, I want the FreeBSD release and source revision pinned, so that changes in upstream base-system inputs are deliberate.
3. As a NetPF developer, I want the ports-tree revision pinned, so that package builds can be repeated against the same software sources.
4. As a NetPF developer, I want the required ports and package options declared in the repository, so that the image package set is reviewable and consistent.
5. As a NetPF developer, I want Poudriere to build packages in an isolated jail, so that host-installed packages do not leak into the appliance image.
6. As a NetPF developer, I want Poudriere's package repository to be the explicit source for image packages, so that the image cannot silently vary with an external repository.
7. As a NetPF developer, I want the FreeBSD base system and kernel built or acquired through a documented, pinned process separate from Poudriere, so that package building and base-system construction have clear responsibilities.
8. As a NetPF developer, I want image assembly to consume only declared base and package artifacts, so that the output can be traced to its inputs.
9. As a NetPF developer, I want the first image to target `amd64`, so that there is one practical platform for validating the initial system foundation.
10. As a developer, I want the image to boot through UEFI in QEMU, so that the build can be validated before dedicated NetPF hardware is selected.
11. As a developer, I want the image's root filesystem on ZFS, so that the base system uses the project's chosen storage foundation.
12. As an operator, I want the OS environment separated from persistent configuration and data, so that future OS replacement does not overwrite appliance state.
13. As a developer, I want the image's GPT, EFI, and ZFS pool/dataset layout documented, so that image assembly and boot behavior are understandable and testable.
14. As a developer, I want a named initial ZFS OS environment, so that a later firmware workflow can build on a stable boot-environment convention.
15. As a developer, I want a QEMU smoke test to detect a failed boot or missing ZFS root, so that an invalid image is not reported as a successful build.
16. As a developer, I want the smoke test to expose boot progress and failure logs, so that failures can be diagnosed without manual image inspection.
17. As a developer, I want each output accompanied by a checksum, so that image transfer or storage corruption can be detected.
18. As a developer, I want a build manifest containing source, ports, package, and configuration identities, so that an image's provenance can be inspected later.
19. As a developer, I want temporary build state isolated from source and output directories, so that clean builds and cleanup are predictable.
20. As a contributor, I want host prerequisites and resource requirements documented, so that I can prepare a supported FreeBSD build host.
21. As a contributor, I want build stages and logs clearly separated, so that I can identify whether a failure occurred in Poudriere, base-system construction, or image assembly.
22. As a NetPF developer, I want the base image to remain minimal and free of unrelated services, so that it is a suitable foundation for the focused network appliance.

## Implementation Decisions

- FreeBSD is the base operating system. The exact supported release/source revision is an explicit build input and must be selected and pinned for the first implementation.
- The first output target is one `amd64` raw disk image, tested with UEFI firmware in QEMU. This validates the system without committing to a physical appliance SKU.
- Poudriere builds declared ports packages in an isolated jail. FreeBSD base/kernel inputs are handled by the corresponding FreeBSD source/release tooling, and a separate assembly stage creates the disk image.
- The image boots from GPT/UEFI and uses a ZFS root pool. The OS environment is separate from persistent configuration and operational data; concrete dataset names and mountpoints are implementation decisions and must be documented.
- The first image includes the minimum FreeBSD components and declared packages needed for a normal console boot. Network product services and a management daemon are not part of this PRD.
- Inputs are pinned or recorded in repository-managed build configuration. Outputs include a raw image, SHA-256 checksum, and machine-readable provenance manifest.
- Initial reproducibility means equivalent image behavior from identical pinned inputs and an auditable input manifest; bit-for-bit reproducibility, signing, and release distribution are later work.
- The primary integration seam is the built image: build it, boot it in QEMU, verify multi-user boot and ZFS-root operation, and fail the build if the smoke test fails.

## Testing Decisions

- Tests should verify observable outputs and behavior: pinned configuration is honored, the declared package repository is used, the disk image has the expected boot/ZFS structure, and the guest reaches multi-user boot with ZFS mounted as root. Avoid tests coupled to internal script names or helper decomposition.
- Test build-configuration validation and package-manifest behavior without invoking full package builds where practical.
- Run an integration build in a supported FreeBSD environment and inspect Poudriere's produced repository and the assembled image.
- Run the image under QEMU with UEFI and capture serial/console output. The smoke test must distinguish reaching multi-user boot from merely starting the boot loader.
- Verify the checksum and manifest are emitted and identify the exact inputs used by the tested image.
- There is no existing application code or comparable test harness in the repository; establish the smallest practical build and image-smoke-test harness as part of this work.

## Out of Scope

- NetPF configuration model, management daemon, CLI, REST API, and Web UI.
- Interface, routing, PF policy, NAT, VPN, DHCP, DNS, or other network-service implementation.
- Multi-architecture support, including `arm64`, and specific physical hardware certification.
- Interactive installation, upgrade orchestration, remote firmware delivery, boot-failure automation, and production recovery UX.
- Firmware signing, secure boot, key management, and artifact distribution.
- Bit-for-bit reproducible images.
- Custom kernel optimization beyond what is required to boot the initial target; hardware-specific kernel tuning is deferred.
- General-purpose package management or arbitrary third-party software installation on the appliance.

## Further Notes

- The PRD treats Poudriere as the ports/package builder, not as a FreeBSD base-system builder. This distinction avoids designing an inaccurate build pipeline.
- The QEMU target is a validation environment, not a product virtualization feature.
- This is the first vertical slice in a larger image-build, ZFS boot-environment, upgrade, and recovery roadmap. The first image establishes conventions but does not claim the future update and rollback workflow is complete.
- Research source: `docs/research.md`, especially the Poudriere firmware direction, ZFS system/state separation, and reproducible image-build workflow.
