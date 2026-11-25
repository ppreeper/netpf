---
status: accepted
---

# Use ZFS for appliance storage

NetPF will use ZFS as its storage foundation. The intended architecture separates the booted OS from persistent appliance configuration and data, enabling firmware-style upgrades without treating configuration as part of the replaceable OS image. Boot-environment upgrade and rollback behavior is the proposed use of ZFS, while the exact pool, dataset, disk, and recovery layouts remain to be designed.
