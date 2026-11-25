---
status: accepted
---

# Build appliance firmware with Poudriere

NetPF will produce complete OS images from controlled source and package inputs, using Poudriere to build the ports package set. FreeBSD base-system and kernel build steps, root filesystem creation, and disk-image assembly are separate stages; Poudriere is not the FreeBSD base-system builder. This fits the focused appliance OS and pairs with ZFS for system storage. The first implementation targets an `amd64` raw GPT/UEFI image, as defined in the [base-system PRD](../prd/0001-poudriere-zfs-base-system.md). The supported FreeBSD release, broader artifact targets, bit-for-bit reproducibility, signing, and update mechanism remain open.
