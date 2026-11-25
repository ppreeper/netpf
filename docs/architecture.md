# NetPF Architecture

**Status:** Working architecture baseline  
**Source:** [Research notes](research.md)

NetPF is a focused, declarative BSD network operating system powered by PF. This document consolidates the architecture direction from the research notes and distinguishes user-stated constraints from design proposals that still need confirmation. It is a blueprint, not a claim that every subsystem or technology choice is final.

## 1. Product direction

NetPF is a network operating system for routing, firewalling, and related network services. It takes the configuration-driven workflow of a network OS, the BSD networking foundation and PF firewall, and the usability of an appliance with CLI, API, and Web UI.

The product is intentionally focused. It is not a general-purpose BSD distribution or a host for arbitrary workloads. Virtualization, user-facing jails/containers, NAS features, and an application marketplace are outside the intended scope.

### Goals

- Provide a consistent CLI, REST API, and Web UI for configuring and operating the system.
- Make networking and firewall capabilities first-class parts of the OS, not features hidden behind a GUI.
- Prefer declarative configuration, validation, and controlled application over ad hoc system-file edits.
- Deliver the OS as a firmware-like release that can be installed, upgraded, and recovered predictably.
- Keep the platform small and purpose-built for network-appliance operation.

### Non-goals

- General-purpose FreeBSD desktop/server use.
- Running arbitrary user applications, VMs, or containers as product features.
- Replicating every feature of commercial security appliances.
- Requiring users to author native PF syntax for ordinary firewall policy.

The broad capability inventory in `research.md` is a product landscape, not an initial release commitment. Routing protocols, HA, IDS/IPS, proxies, and other services should be prioritized separately.

## 2. Decision status

| Direction | Status | Notes |
| --- | --- | --- |
| Focused BSD network OS rather than a general-purpose distribution | Accepted direction | Explicitly stated project scope; see [ADR 0001](adr/0001-focused-network-operating-system.md). |
| Exclude user-facing jails, VMs, and container platform | Accepted constraint | Explicitly stated; see ADR 0001. |
| PF as the defining firewall foundation | Accepted preference | The BSD family and exact PF implementation remain open; see [ADR 0002](adr/0002-pf-as-firewall-foundation.md). |
| ZFS for storage | Accepted direction | Exact dataset, pool, and boot layout remain open; see [ADR 0003](adr/0003-zfs-for-system-and-persistent-state.md). |
| FreeBSD as the base operating system | Accepted direction | The initial platform is FreeBSD; exact supported release and kernel configuration remain to be pinned. See [ADR 0006](adr/0006-freebsd-as-the-base-operating-system.md). |
| Poudriere-built firmware-style OS images | Accepted direction | Poudriere builds the ports package set; FreeBSD base and image assembly are separate build stages. See [ADR 0004](adr/0004-firmware-built-with-poudriere.md). |
| One declarative configuration model shared by CLI, API, and UI | Proposed architecture | Strongly recommended by the research; details and approval remain open. |
| Transactional configuration engine and central management daemon | Proposed architecture | Preserve the recommended boundary; daemon language and internal design are undecided. |

## 3. System architecture

The architecture separates user-facing management, the control plane, network services, and the BSD platform. The management plane translates desired configuration into platform state; it is not itself the packet-forwarding data plane.

```text
┌──────────────────────────────────────────────────────────────┐
│                         User clients                         │
│                 CLI       REST API       Web UI              │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│                     Management control plane                  │
│                                                              │
│ Configuration model │ validation │ transactions │ audit/state│
│           Proposed central management daemon                 │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│                     Network service layer                     │
│ Interfaces │ routing │ PF/NAT │ VPN │ DHCP/DNS/NTP │ QoS/HA  │
└──────────────────────────────┬───────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────┐
│                       BSD platform                            │
│ Kernel │ networking │ PF │ drivers │ crypto │ ZFS │ boot      │
└──────────────────────────────────────────────────────────────┘
```

The diagram is a logical decomposition, not a required process topology. Services may use native BSD facilities or dedicated service software behind controlled subsystem interfaces.

### Control-plane responsibilities

The proposed management component owns the appliance configuration lifecycle and coordinates subsystem controllers. Controllers provide bounded interfaces for platform-specific operations such as interfaces, routes, PF, VPN, and system/firmware state. Subsystems should not independently rewrite one another's generated configuration or bypass the configuration lifecycle for managed settings.

The research suggests `netpfd` as the daemon name and `netpf` as the CLI name, with the daemon serving the REST API. These are naming proposals, not finalized executable or implementation decisions. Go was suggested for the daemon but is not selected here.

## 4. Configuration architecture

### Canonical model

The proposed design has one typed, versioned configuration model covering at least:

- System identity and platform settings.
- Physical and logical interfaces, including VLANs, bridges, LAGs, and tunnels.
- Addressing and routing.
- Firewall policy and NAT.
- VPNs and network services.
- Appliance-level service and operational settings.

The model is the shared contract used by the CLI, REST API, and Web UI. A serialized configuration file may be used for persistence or interchange, but should not accidentally become a separate, incompatible API. The serialization format and schema evolution policy remain undecided.

Network policy should refer to logical interface identity where practical, rather than assuming a fixed set of hardware names such as `em0` and `em1`. Hardware discovery and the mapping from discovered NICs to configured roles need a later design.

### Candidate, running, saved, and active state

The proposed lifecycle distinguishes:

- **Candidate configuration:** the operator's uncommitted edits.
- **Running configuration:** the committed desired configuration held by the system.
- **Saved configuration:** the configuration selected to persist across reboot.
- **Active state:** the state currently applied to the OS and network services.

The CLI should support familiar operations such as `show`, `compare`, `validate`, `commit`, `rollback`, `discard`, and `save`. A confirmed commit with automatic rollback is recommended for remote changes that might interrupt management access.

### Transaction flow

```text
Candidate
   → parse/schema validation
   → semantic validation and dependency resolution
   → build an apply plan
   → generate subsystem configuration
   → validate generated configuration
   → apply changes
   → verify operational state
   → finalize commit (or roll back)
```

The transaction engine should report failures at the relevant stage and avoid claiming success until application and verification have completed. Exact atomicity guarantees depend on the platform operations and must be specified per subsystem.

## 5. Networking and service boundaries

### Interfaces

Model physical interfaces and logical interfaces (for example VLAN, bridge, LAG, loopback, and supported tunnels) as related but distinct resources. Dependents such as routes and firewall rules refer to those resources through stable configuration identities. Initial interface support should be kept small and expanded as hardware support is validated.

### Routing

Routing is a first-class subsystem, separate from firewall policy. Start with interface/connected routes and static routes. Policy routing and dynamic routing protocols such as BGP and OSPF are later capabilities, not prerequisites for the initial platform. The research proposes using FRR for dynamic routing, but neither FRR nor the initial protocol set is selected.

### PF and NAT

PF is the preferred firewall foundation. The proposed implementation translates the platform-neutral firewall/NAT model into generated PF configuration and applies it through the native PF control interface. PF anchors are a candidate mechanism for keeping independently managed rule groups separate. PF syntax remains a backend detail for ordinary users, with an expert shell/tooling escape hatch retained.

PF and NAT need explicit validation, application, and operational-status boundaries. Rules, tables, state inspection, and NAT should be modeled as policy and state—not as unmanaged snippets of generated text.

### VPN and network services

VPN implementations may include WireGuard, IPsec, and potentially OpenVPN. Use subsystem-specific configuration where protocols differ; do not force every VPN into an artificial identical feature set. VPN configuration must integrate intentionally with interfaces, routes, and firewall policy.

DHCP, DNS, NTP, certificates, QoS, HA, and monitoring are candidates for the service layer. Their providers, packaging, dependencies, and delivery phases are still open. The initial release should avoid treating the entire research feature inventory as mandatory scope.

## 6. Management interfaces and observability

The CLI, REST API, and Web UI are peer clients of the management model. The UI should use the same API available to automation rather than owning private configuration behavior. The REST API should expose both desired configuration and operational state, and should have a published contract (OpenAPI was recommended, not yet chosen).

The proposed API can be organized around system, interfaces, routes, firewall, NAT, VPN, services, status, and monitoring. Authentication, authorization, API versioning, and remote-access policy require a dedicated security/API design.

Structured logs, audit events, system events, and useful metrics are architectural concerns. Initial observability should include configuration changes and failures, interface/link state, route state, firewall state, and firmware activity. Export protocols and remote collectors can be selected as requirements become concrete.

## 7. OS image, storage, and recovery

### Firmware build direction

The release pipeline builds a complete appliance image from pinned FreeBSD/base sources, kernel configuration, ports/packages, and NetPF software. Poudriere builds the ports package set; FreeBSD base/kernel construction and image assembly are separate stages. The output is treated as a versioned firmware release, not as a mutable general-purpose package installation. The first build slice is specified in the [Poudriere/ZFS base-system PRD](prd/0001-poudriere-zfs-base-system.md).

The first implementation target is an `amd64` raw GPT/UEFI image, as scoped in the [base-system PRD](prd/0001-poudriere-zfs-base-system.md). Broader image formats and CPU architectures, release provenance, signing keys, and exact reproducibility guarantees remain open. Signed artifacts and signature verification are recommended but remain design work.

### ZFS and state separation

ZFS is the selected storage direction. The design should separate the booted OS environment from persistent appliance configuration and operational data so that an OS upgrade does not overwrite configuration. Logs may have their own retention and capacity policy. The exact datasets, mountpoints, encryption approach, and treatment of certificates/secrets remain open.

ZFS boot environments are the proposed basis for installing a new OS version alongside the current one, selecting it for the next boot, and returning to a known-good environment after failed boot or health checks. A firmware update should verify its artifact before installation and retain an explicit recovery path. These operational details still require platform-specific validation.

### Recovery

Recovery is part of the product architecture. The plan should cover console access, selection of a prior boot environment, firmware reinstall or rescue, and configuration backup/restore. A failed management-plane update must not leave the appliance without a documented recovery route.

## 8. Security boundaries

- Keep the installed OS focused and minimize enabled services.
- Treat the management plane as privileged; validate and authorize requests before applying OS changes.
- Isolate platform-specific privileged operations behind narrow subsystem controllers.
- Record configuration changes and firmware actions in an audit trail.
- Preserve direct BSD diagnostic tools for expert troubleshooting, while making clear how unmanaged shell changes interact with declarative state.
- Design firmware artifact verification, secret storage, management access, and recovery as explicit security decisions.

This document does not yet define a complete threat model, authentication system, secure-boot requirement, or key lifecycle.

## 9. Build, test, and delivery shape

The research recommends a monorepo organized around management components, API/UI, FreeBSD integration, image building, and tests. This is a candidate layout rather than a binding directory structure. Keep build inputs and release outputs traceable to source revisions and package sets.

Testing should include unit and schema/validation tests, subsystem compiler tests, API/CLI tests, virtual network topology tests, and boot/install/upgrade/rollback tests. Network behavior should be verified across realistic interface, route, firewall, and NAT combinations; image boot and recovery paths need automated coverage where practical.

## 10. Suggested implementation sequence

This sequence is a planning proposal, not a promise of feature scope:

1. Pin the first FreeBSD release/build inputs and produce a bootable FreeBSD/ZFS base image with a console.
2. Implement the configuration model, persistence, validation, and transaction lifecycle.
3. Add interface configuration, addressing, and static routing.
4. Add PF policy and NAT generation/application, with integration tests.
5. Expose the model through the API and then build the UI as an API client.
6. Add VPNs and selected network services.
7. Add advanced routing, HA, signed firmware distribution, and production recovery features according to validated needs.

## 11. Open architecture decisions

The following must be resolved before their dependent implementation is treated as fixed:

1. Which FreeBSD release/source revision and kernel configuration are supported first, and what PF implementation/version is shipped?
2. What are the management daemon language, process model, and privileged-operation boundary? Go and `netpfd` were suggestions only.
3. What is the typed configuration schema, serialized representation, and compatibility/migration policy?
4. How do candidate/running/saved configuration and commit-confirm rollback behave under process crash, reboot, or partial subsystem failure?
5. What REST authentication/authorization model and API compatibility policy are required?
6. What are the initial hardware/CPU targets, disk layout, and ZFS boot-environment implementation?
7. How are Poudriere inputs pinned, images assembled, releases signed, keys managed, and updates delivered?
8. Which networking services are in the first usable release, beyond interfaces, static routes, PF, and NAT?
9. What is the supported recovery and configuration-backup workflow?

## Related decisions

- [ADR 0001: Focused network operating system](adr/0001-focused-network-operating-system.md)
- [ADR 0002: PF as the firewall foundation](adr/0002-pf-as-firewall-foundation.md)
- [ADR 0003: ZFS for system and persistent state](adr/0003-zfs-for-system-and-persistent-state.md)
- [ADR 0004: Firmware built with Poudriere](adr/0004-firmware-built-with-poudriere.md)
- [ADR 0005: Shared declarative configuration](adr/0005-shared-declarative-configuration.md)
- [ADR 0006: FreeBSD as the base operating system](adr/0006-freebsd-as-the-base-operating-system.md)
