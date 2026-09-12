# netpf research

**prompt**

What are the core features of firewalls, especially open source ones, including the servers/routing/VPN; i have used fortinet, opnsense, vyatta, vyos, and openbsd with pf

**response**

Yes. If you look past the product names—FortiGate, OPNsense, VyOS, Vyatta, pf, etc.—most firewall/router platforms are really a combination of a few major subsystems.

A useful way to think about an open-source firewall appliance is:

> **Network interfaces + switching/bridging + routing + firewall/NAT + VPN + services + management + observability**

Here's how I'd break down the feature set.

## 1. Network interface management

The foundation is managing physical and virtual interfaces:

- Ethernet interfaces
- VLANs / 802.1Q
- Link aggregation / LACP
- Bridges
- Bonding
- Wireless interfaces
- PPPoE
- GRE interfaces
- Tunnel interfaces
- Loopback interfaces
- Virtual interfaces
- Hardware offloading
- MTU / MSS configuration
- IPv4 and IPv6 addressing
- DHCP client
- Static addressing
- IPv6 SLAAC/DHCPv6

For an appliance, you generally want a clean abstraction such as:

```text
Interfaces
├── Physical
│   ├── igb0
│   ├── igb1
│   └── ix0
│
├── VLAN
│   ├── vlan10
│   ├── vlan20
│   └── vlan30
│
├── Bridge
│   └── bridge0
│
├── LAG
│   └── lagg0
│
└── Tunnel
    ├── wg0
    ├── gre0
    └── ipsec0
```

This layer is surprisingly important because everything else depends upon it.

---

# 2. Switching / Layer 2

This tends to be more important in OPNsense/pfSense than in VyOS.

Core functionality:

- VLANs
- VLAN tagging/untagging
- Bridges
- STP/RSTP
- LACP
- MAC filtering
- Broadcast domains
- Port isolation
- QinQ
- MAC address tables
- LLDP
- 802.1X
- DHCP snooping
- ARP inspection
- Multicast/IGMP

There is an important architectural distinction here.

A VyOS-style router is generally:

```text
              Router
                 |
       +---------+---------+
       |                   |
      WAN                 LAN
```

while an OPNsense/pfSense appliance can behave much more like:

```text
                 Firewall
              /     |      \
           WAN    VLAN10   VLAN20
                    |
                  Bridge
```

---

# 3. Routing

This is one of the major pillars.

### Basic routing

- Static routes
- Connected routes
- Default routes
- Policy-based routing
- Routing tables
- Route metrics
- Administrative distance
- ECMP
- Blackhole routes
- Null routes

### Dynamic routing

For serious router/firewall systems:

- OSPF
- BGP
- RIP
- IS-IS
- OSPFv3
- BFD
- VRRP
- PIM/multicast routing

And increasingly:

- EVPN
- VXLAN
- Segment routing

For an SMB firewall, OSPF/BGP are probably the most useful dynamic protocols.

VyOS is particularly strong here because it is fundamentally a router that also happens to have a firewall.

---

# 4. Firewall

This is the obvious core.

At minimum:

### Stateful firewall

Rules based on:

- Source IP
- Destination IP
- Source port
- Destination port
- Protocol
- Interface
- VLAN
- Address group
- Port group
- Connection state

For example:

```text
LAN → Internet
source: LAN_NET
destination: ANY
service: HTTPS
action: ALLOW
```

### Stateful tracking

The firewall needs to understand:

```text
NEW
ESTABLISHED
RELATED
INVALID
```

rather than treating every packet independently.

---

# 5. NAT

NAT is effectively its own major subsystem.

### Source NAT

Typical:

```text
10.10.120.0/23
       ↓
Public IP
```

Including:

- Automatic outbound NAT
- Manual outbound NAT
- 1:1 NAT
- SNAT
- Masquerading

### Destination NAT

- Port forwarding
- DNAT
- Virtual IPs
- Reflection/hairpin NAT

For example:

```text
Internet
   |
203.0.113.10:443
   |
   ↓
10.10.120.50:443
```

---

# 6. VPN

VPN is another enormous category.

## IPsec

Usually:

- IKEv1/IKEv2
- Site-to-site
- Road warrior
- PSK
- Certificates
- PFS
- Multiple proposals
- NAT traversal
- DPD
- Route-based IPsec
- Policy-based IPsec

For example:

```text
Edmonton
10.10.0.0/16
      |
   IPsec
      |
Calgary
10.20.0.0/16
```

## WireGuard

Increasingly essential:

- Site-to-site
- Remote access
- Peer management
- Allowed IPs
- Persistent keepalive
- Routing integration

## OpenVPN

Still useful for:

- Remote access
- Site-to-site
- Certificate authentication
- TCP/UDP

## Other tunnels

Depending on the platform:

- GRE
- IP-in-IP
- VXLAN
- SIT
- L2TP
- PPP
- SSTP

---

# 7. DHCP

A firewall is frequently also the network's DHCP server.

Features:

- DHCPv4
- DHCPv6
- Reservations
- Option configuration
- Multiple scopes
- Lease management
- PXE
- DNS server assignment
- NTP server assignment
- Gateway assignment
- DHCP relay

For example:

```text
VLAN 10
10.10.10.0/24

Gateway: 10.10.10.1
DNS:     10.10.10.1
Range:   .100-.200
```

---

# 8. DNS

This is another service that commonly lives on the firewall.

Typical capabilities:

- DNS resolver
- DNS forwarder
- Local host records
- DHCP registration
- DNS overrides
- Split DNS
- DNSSEC
- DNS filtering
- DNS over TLS
- DNS over HTTPS
- Conditional forwarding

A particularly useful enterprise feature is:

```text
corp.example.com → internal DNS
everything else → upstream DNS
```

---

# 9. High availability

Important for serious installations.

Typically:

```text
             Internet
                |
          +-----+-----+
          |           |
       FW-A          FW-B
          |           |
          +-----+-----+
                |
               LAN
```

Features include:

- VRRP
- CARP
- Stateful failover
- Configuration synchronization
- Floating IPs
- Gateway failover
- Connection-state synchronization

OPNsense/pfSense are particularly good examples of this appliance-oriented approach.

---

# 10. Multi-WAN

Very common in SMB environments.

For example:

```text
          ISP 1
            |
         +--+--+
         |     |
       Firewall
         |     |
         +--+--+
            |
          ISP 2
```

Features:

- Multiple gateways
- Gateway monitoring
- Failover
- Load balancing
- Policy-based routing
- Sticky connections
- Gateway groups
- Health checks
- Automatic failback

A useful distinction is:

**Failover**

```text
ISP1 → primary
ISP2 → backup
```

versus:

**Load balancing**

```text
ISP1 ─┐
      ├→ firewall → Internet
ISP2 ─┘
```

---

# 11. Traffic shaping / QoS

Often overlooked.

Capabilities:

- Bandwidth limits
- Queues
- Priority
- DSCP
- Traffic classification
- Per-host limits
- Per-application limits
- Fair queuing
- WAN shaping

For example:

```text
VoIP       → highest priority
ERP        → high
Web        → normal
Backups    → low
Torrents   → very low
```

---

# 12. IDS / IPS

This is where the distinction between a basic firewall and a security appliance becomes significant.

Common open-source engines include:

- Suricata
- Snort
- Zeek

### IDS

Detect:

```text
"Something suspicious happened."
```

### IPS

Detect and block:

```text
"Something suspicious happened → DROP."
```

Suricata is particularly common in OPNsense/pfSense environments.

---

# 13. Web/content filtering

Depending on the platform:

- HTTP proxy
- HTTPS interception
- URL filtering
- DNS filtering
- Malware filtering
- Category filtering
- Ad blocking
- Safe-search enforcement

This has become less central as encrypted traffic has become ubiquitous, so DNS-based filtering is often more practical.

---

# 14. Authentication

An enterprise firewall usually becomes an authentication point too.

Protocols/services:

- Local users
- LDAP
- Active Directory
- RADIUS
- TACACS+
- SAML/OIDC
- MFA
- Certificates

Especially useful for VPN access.

For example:

```text
VPN
 |
RADIUS
 |
Active Directory
 |
MFA
```

---

# 15. Certificate management

This deserves its own subsystem.

You need:

- Certificate authorities
- Certificates
- Private keys
- CSR generation
- Certificate renewal
- ACME / Let's Encrypt
- Certificate revocation
- Certificate chains

And then certificates can be consumed by:

```text
HTTPS
VPN
IPsec
LDAP
802.1X
Reverse proxy
```

---

# 16. Reverse proxy / load balancing

Many modern firewall distributions also act as an edge application gateway.

For example:

```text
Internet
    |
Firewall
    |
Reverse Proxy
    |
+---+---+---+
|   |   |   |
Web1 Web2 Web3
```

Features:

- HTTP/HTTPS
- TLS termination
- Virtual hosts
- Health checks
- Load balancing
- HTTP redirects
- WebSocket support
- Header manipulation
- Rate limiting

Common software:

- HAProxy
- nginx
- Caddy

---

# 17. Routing services

A firewall often provides services that aren't strictly "firewalling":

- NTP
- DHCP
- DNS
- TFTP
- PXE
- SNMP
- mDNS reflector
- UPnP
- Dynamic DNS
- Wake-on-LAN
- Captive portal

---

# 18. Dynamic DNS

Especially useful when the WAN address changes.

```text
WAN IP
203.0.113.50
      ↓
firewall.example.com
```

Providers might include:

- Cloudflare
- DynDNS
- No-IP
- Route53
- etc.

---

# 19. Monitoring / observability

A serious firewall should expose much more than a GUI.

### Logs

- Firewall logs
- NAT logs
- DHCP logs
- DNS logs
- VPN logs
- Authentication logs
- Routing logs
- System logs

### Metrics

- CPU
- RAM
- Disk
- Interface bandwidth
- Packet rate
- Connections
- NAT states
- VPN tunnels
- Gateway health

### Protocols

- SNMP
- Syslog
- NetFlow/IPFIX
- Prometheus
- REST API

This is an area where an open-source firewall can become extremely powerful when integrated with something like:

```text
Firewall
   |
   +── Prometheus
   +── Loki
   +── Grafana
   +── ntfy
```

---

# 20. Management plane

This is something I would explicitly separate from the firewall itself.

### GUI

- Configuration
- Status
- Logs
- Monitoring
- Diagnostics

### CLI

- Shell
- Routing commands
- Firewall commands
- Packet capture
- Interface diagnostics

### API

Modern systems should have a complete API:

```text
GET    /interfaces
POST   /interfaces
GET    /firewall/rules
POST   /firewall/rules
PUT    /firewall/rules/:id
DELETE /firewall/rules/:id
```

### Configuration

Ideally:

```text
configuration
     ↓
validation
     ↓
generated system configuration
     ↓
atomic application
```

This is one of the areas where VyOS's configuration model is conceptually quite different from traditional BSD firewall appliances.

---

# 21. Diagnostics

A good firewall should have excellent troubleshooting tools:

- Ping
- Traceroute
- DNS lookup
- ARP table
- Neighbor table
- Routing table
- Firewall state table
- NAT state table
- Packet capture
- Interface statistics
- Connection tracking
- TCP connection tests
- Port tests

Being able to do:

```text
packet capture:
LAN → firewall → WAN
```

from the GUI is incredibly valuable.

---

# 22. Hardware acceleration

For an appliance-oriented system:

- AES-NI
- QAT
- NIC offloading
- RSS
- multiqueue
- checksum offload
- TSO/LRO
- crypto acceleration

This can dramatically affect VPN and firewall throughput.

---

# 23. Virtualization / container integration

Modern open-source firewall systems increasingly need to run as:

```text
Physical appliance
VM
Cloud instance
Container
```

with:

- VirtIO
- SR-IOV
- PCI passthrough
- VLAN trunking
- cloud-init
- AWS/Azure/GCP networking

VyOS is particularly natural as a VM/cloud router.

---

# 24. Security hardening

The underlying OS matters enormously.

Things such as:

- Secure boot
- Minimal services
- Privilege separation
- chroot/jails
- MAC frameworks
- ASLR
- firewall self-protection
- management-plane isolation
- SSH hardening
- MFA
- audit logging
- signed updates
- automatic security updates

This is one reason OpenBSD/pf has historically been interesting: the firewall isn't just an application sitting on a generic OS—the OS itself is designed around security.

---

# A useful overall architecture

If you were designing your own open-source firewall/router, I'd organize it approximately like this:

```text
                    ┌─────────────────────────┐
                    │     Management Plane    │
                    │                         │
                    │ Web UI │ CLI │ REST API │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │     Configuration       │
                    │                         │
                    │ validation / transactions│
                    │ state / config database  │
                    └────────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼───────┐       ┌────────▼────────┐       ┌───────▼───────┐
│   Interfaces  │       │    Routing      │       │   Security    │
│               │       │                 │       │               │
│ Ethernet      │       │ Static          │       │ Firewall      │
│ VLAN          │       │ OSPF            │       │ NAT           │
│ Bridge        │       │ BGP             │       │ IDS/IPS       │
│ LAG           │       │ Policy routing  │       │ Filtering     │
└───────┬───────┘       └────────┬────────┘       └───────┬───────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │       VPN / Tunnels     │
                    │                         │
                    │ IPsec / WireGuard /     │
                    │ OpenVPN / GRE / VXLAN   │
                    └────────────┬────────────┘
                                 │
             ┌───────────────────┼───────────────────┐
             │                   │                   │
       ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐
       │   DHCP    │       │    DNS    │       │   Proxy   │
       │           │       │           │       │ / HAProxy │
       └───────────┘       └───────────┘       └───────────┘
                                 │
                    ┌────────────▼────────────┐
                    │ Observability           │
                    │                         │
                    │ Logs / Metrics / SNMP   │
                    │ NetFlow / Alerts        │
                    └─────────────────────────┘
```

## How your examples fit

Your experience actually covers several different philosophies:

| System           | Fundamental philosophy                   |
| ---------------- | ---------------------------------------- |
| **OpenBSD + pf** | Secure OS + elegant packet filter        |
| **Vyatta**       | Router/network OS                        |
| **VyOS**         | Router/network OS + open-source Linux    |
| **OPNsense**     | Firewall appliance + services + GUI      |
| **FortiGate**    | Integrated commercial security appliance |

I'd particularly distinguish **OPNsense/pfSense** from **VyOS**.

OPNsense thinks roughly:

> "I am the firewall at the edge of your network, and I'll provide most of the network services you need."

VyOS thinks:

> "I am a network operating system; give me interfaces, routing protocols, VPNs and firewalling, and I'll build whatever topology you need."

And OpenBSD/pf is closer to:

> "Here is a very good operating system and a very powerful packet-filtering/networking primitive; compose the rest yourself."

That distinction becomes **very interesting if you're considering building the networking layer for Centria or another appliance/product**. I would actually model it as **a network OS with independent services**, rather than making "firewall" the center of the architecture.

**prompt**

I was thinking about hos i like the vyos cli and api and a good we interface for them, but I like the power of the pf firewall and the complete os of using a bsd

**response**

Yes — I think those preferences point toward a pretty compelling design: **take the network-OS architecture of VyOS, but build it on top of BSD networking/pf rather than Linux/netfilter**.

The interesting part is that these aren't really conflicting preferences.

### The combination you're describing

I'd think of it as:

> **VyOS's configuration/API philosophy + OpenBSD's networking/security primitives + a modern BSD base OS + OPNsense's usability.**

Something like:

```text
                    Web UI
                       │
                    REST API
                       │
                     CLI
                       │
             ┌─────────▼─────────┐
             │ Configuration DB   │
             │                    │
             │ declarative state  │
             └─────────┬─────────┘
                       │
             ┌─────────▼─────────┐
             │ Network Services   │
             ├────────────────────┤
             │ Interfaces         │
             │ Routing             │
             │ Firewall            │
             │ NAT                 │
             │ VPN                 │
             │ DHCP                │
             │ DNS                 │
             │ QoS                 │
             │ HA                  │
             └─────────┬──────────┘
                       │
             ┌─────────▼──────────┐
             │       BSD OS       │
             │                    │
             │ pf / routing /     │
             │ sockets / network  │
             │ drivers / jails    │
             └────────────────────┘
```

And **pf would be a first-class subsystem**, rather than just one feature exposed by a GUI.

---

## The thing I really like about the VyOS approach

The most important thing to copy from VyOS isn't necessarily its syntax.

It's the **configuration architecture**.

Instead of the CLI directly manipulating the system:

```text
set firewall rule ...
→ immediately modify firewall
```

you have:

```text
                 configuration
                       │
              ┌────────▼────────┐
              │ desired state   │
              └────────┬────────┘
                       │
                   validate
                       │
                 generate/apply
                       │
              ┌────────▼────────┐
              │ actual system   │
              └─────────────────┘
```

That gives you a really nice property:

**CLI, API and Web UI all operate on exactly the same configuration model.**

For example:

```text
set interfaces ethernet eth0 address 192.168.1.1/24
set interfaces ethernet eth0 description "LAN"

set firewall ipv4 name LAN-IN default-action drop
set firewall ipv4 name LAN-IN rule 10 action accept
set firewall ipv4 name LAN-IN rule 10 protocol tcp
set firewall ipv4 name LAN-IN rule 10 destination port 443
```

Then the API might manipulate the exact same objects:

```json
{
  "interfaces": {
    "eth0": {
      "address": ["192.168.1.1/24"],
      "description": "LAN"
    }
  }
}
```

And the web interface is just another client.

That architecture is **much more important than whether the underlying OS is Linux or BSD**.

---

# And pf gives you a really nice foundation

The other thing you're identifying is that pf is more than simply "a firewall."

OpenBSD's networking stack gives you a very coherent set of primitives:

- pf
- NAT
- tables
- anchors
- state tracking
- queues
- ALTQ-related concepts
- routing
- VLANs
- bridges
- CARP
- IPsec
- WireGuard
- jails / isolation mechanisms depending on BSD
- packet capture
- excellent networking utilities

So instead of building a firewall application that happens to run on an OS, you can build a **network operating system around the OS's networking facilities**.

---

# I would actually consider FreeBSD as the base

If the goal is something like:

> "VyOS, but BSD"

I'd seriously investigate **FreeBSD** rather than OpenBSD as the base.

Not because pf on OpenBSD isn't excellent—it is—but because FreeBSD gives you some particularly attractive things for an appliance/network OS:

- ZFS
- jails
- bhyve
- strong hardware support
- excellent networking stack
- DPDK/netmap ecosystem
- mature driver support
- excellent storage capabilities
- SMP scalability
- pf
- CARP
- VLANs
- lagg
- bridges
- routing
- WireGuard
- IPsec

It also gives you a very nice foundation for a **general-purpose network appliance OS**, rather than limiting yourself to firewall duties.

The tradeoff is that **OpenBSD's pf is the reference implementation**, and FreeBSD's pf has diverged from OpenBSD's current pf. That's something you'd need to decide explicitly.

---

# The really interesting architecture

If I were designing this, I'd avoid having the CLI itself know how to configure pf.

Instead:

```text
                     ┌───────────────┐
                     │    Web UI     │
                     └───────┬───────┘
                             │
                     ┌───────▼───────┐
                     │     REST      │
                     └───────┬───────┘
                             │
                     ┌───────▼───────┐
                     │ Configuration │
                     │     Model     │
                     └───────┬───────┘
                             │
                     ┌───────▼───────┐
                     │   Services    │
                     └───────┬───────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
     ┌────▼────┐       ┌─────▼────┐       ┌─────▼─────┐
     │   pf    │       │ Routing  │       │ Interfaces│
     └─────────┘       └──────────┘       └───────────┘
```

So the configuration model might say:

```text
firewall:
    LAN-IN:
        default: drop

        rule 10:
            action: accept
            protocol: tcp
            destination-port: 443
```

Then the firewall backend generates:

```pf
table <webservers> { 10.10.20.10, 10.10.20.11 }

block in on vlan10

pass in on vlan10 proto tcp \
    to <webservers> port 443 \
    keep state
```

The user **never needs to know that pf syntax exists**.

But an expert can still get down to the underlying OS when necessary.

---

# And I'd preserve an "escape hatch"

This is something I think OPNsense and VyOS both demonstrate in different ways.

You want:

### Normal user

```text
Web UI
```

### Network administrator

```text
CLI
```

### Automation

```text
REST API
```

### Expert / developer

```text
BSD shell
pfctl
route
ifconfig
tcpdump
sysctl
netstat
```

So you're never trapped behind the abstraction.

That's particularly valuable for the kind of system you're describing.

---

## The CLI could be very good

You could have a VyOS-inspired hierarchical CLI:

```text
configure

set system hostname edge01

set interfaces ethernet em0 description "WAN"
set interfaces ethernet em0 address dhcp

set interfaces ethernet em1 description "LAN"
set interfaces ethernet em1 address 10.10.120.1/23

set interfaces ethernet em1 vif 10 address 10.10.10.1/24

set firewall ipv4 name LAN-IN default-action drop
set firewall ipv4 name LAN-IN rule 10 action accept
set firewall ipv4 name LAN-IN rule 10 protocol tcp
set firewall ipv4 name LAN-IN rule 10 destination port 443

commit
save
```

And importantly:

```text
commit
```

doesn't mean "execute 500 commands."

It means:

> Take the new desired configuration, validate the complete configuration, generate the affected subsystem configuration, and atomically apply it.

That's a **very strong model** for a network appliance.

---

# I'd also separate running and saved configuration

Something like:

```text
                 ┌──────────────┐
                 │ saved config │
                 └──────┬───────┘
                        │
                      load
                        │
                 ┌──────▼───────┐
                 │ running      │
                 │ configuration│
                 └──────┬───────┘
                        │
                      commit
                        │
                 ┌──────▼───────┐
                 │ active system│
                 └──────────────┘
```

Then:

```text
show configuration
show configuration commands
compare
commit
commit-confirm
rollback
save
```

A **commit-confirm** feature is particularly valuable on remotely administered firewalls:

```text
commit-confirm 5
```

If you accidentally lock yourself out, the system automatically rolls back after five minutes unless you confirm the commit.

That's one of those features that makes a network OS feel _professional_.

---

# Where I think this could become especially interesting

You could build the system around a relatively small number of **core primitives**:

### Layer 1 — OS

```text
FreeBSD
```

### Layer 2 — networking abstraction

```text
interfaces
VLAN
bridge
LAG
CARP
routing
```

### Layer 3 — security

```text
pf
NAT
tables
states
queues
```

### Layer 4 — network protocols

```text
BGP
OSPF
DHCP
DNS
NTP
IPsec
WireGuard
GRE
```

### Layer 5 — platform

```text
configuration
CLI
REST API
Web UI
logging
metrics
packages
updates
```

And then applications/services become optional:

```text
HAProxy
Suricata
Unbound
FRR
etc.
```

That gives you something that feels much more like a **network operating system** than "an appliance running a firewall GUI."

And honestly, given that you've used **FortiGate + OPNsense + VyOS/Vyatta + pf**, you have a pretty good perspective for designing such a thing because you've seen the strengths of all three philosophies: **commercial integrated appliance, BSD firewall appliance, and declarative network OS**.

**prompt**

I don't want any jails/vm extras, I want it to be very focused, using zfs and i was thinking of using the poudriere image approach to make firmware like os images

**response**

That actually makes the architecture much clearer. I would **not** think of it as a general-purpose FreeBSD distribution. I'd think of it as a **small, immutable-ish network appliance OS built from FreeBSD**.

Your idea of using **ZFS + poudriere to produce complete firmware images** fits that extremely well.

### The design I'd aim for

```text
                    Network Appliance
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  Web UI             CLI              REST API             │
│    │                 │                  │                │
│    └─────────────────┼──────────────────┘                │
│                      │                                   │
│              Configuration Engine                        │
│                      │                                   │
│          ┌───────────┼────────────┐                      │
│          │           │            │                      │
│       Interfaces   Routing       pf                     │
│          │           │            │                      │
│          └───────────┼────────────┘                      │
│                      │                                   │
│             Network Services                             │
│                                                          │
│ DHCP / DNS / NTP / VPN / HA / QoS / etc.                │
│                                                          │
├──────────────────────────────────────────────────────────┤
│                      FreeBSD                             │
│                                                          │
│             ZFS + kernel + drivers                       │
└──────────────────────────────────────────────────────────┘
```

And deliberately **nothing else**.

No:

- bhyve
- jails as a user feature
- container platform
- application marketplace
- arbitrary third-party software
- "run your own stuff" environment

The OS exists to run **the network appliance**.

---

# Poudriere is a very good fit

I'd go even further than simply using poudriere to build packages.

I'd make the **entire OS reproducible from a source tree**.

Something conceptually like:

```text
networkos/
├── src/
│   └── freebsd/
│
├── ports/
│   ├── network/
│   ├── routing/
│   ├── firewall/
│   └── ui/
│
├── config/
│   ├── kernel/
│   ├── rc/
│   └── appliance/
│
├── poudriere/
│   └── ...
│
├── images/
│   ├── amd64/
│   └── arm64/
│
└── build/
```

Then:

```text
source
   │
   ├── FreeBSD base
   ├── kernel
   ├── ports
   └── your software
          │
          ▼
      poudriere
          │
          ▼
     packages
          │
          ▼
      root filesystem
          │
          ▼
       ZFS image
          │
          ▼
      firmware.img
```

That gives you a **firmware release**, rather than something that feels like "FreeBSD with some packages installed."

---

# ZFS makes the upgrade story particularly nice

This is probably the part I'd emphasize most.

Instead of doing:

```text
upgrade packages
upgrade kernel
upgrade random files
hope everything works
```

you could have:

```text
          Current
        ┌──────────┐
        │  OS-A    │
        │ running  │
        └────┬─────┘
             │
             │ install
             ▼
        ┌──────────┐
        │  OS-B    │
        │ new      │
        └──────────┘
```

Then reboot into B.

If B fails:

```text
OS-B
 ↓
boot failure
 ↓
rollback
 ↓
OS-A
```

ZFS snapshots/boot environments make this model very attractive.

You can essentially make the operating system **versioned**.

---

# I would separate OS state from configuration

This is particularly important for a firewall.

For example:

```text
ZFS
│
├── system
│   └── OS installation
│
├── config
│   └── appliance configuration
│
├── data
│   └── persistent operational data
│
└── logs
```

Then an OS update shouldn't fundamentally modify the configuration.

You could have:

```text
OS 1.4.2
   │
   ├── configuration
   ├── certificates
   └── logs
       ↓
OS 1.5.0
```

The new firmware gets mounted/booted while the configuration persists.

---

# And this meshes beautifully with the VyOS configuration model

The configuration shouldn't be the OS.

I'd make it its own declarative data structure:

```text
/config/config.yaml
```

or perhaps JSON/TOML/a database.

Then:

```text
CLI ─────┐
         │
API ─────┼──→ Config Engine ──→ generated system state
         │
Web ─────┘
```

For example:

```text
configuration
├── system
├── interfaces
├── vlans
├── bridges
├── routing
├── firewall
├── nat
├── vpn
├── dhcp
├── dns
├── ntp
├── qos
├── high-availability
└── services
```

This gives you the **VyOS experience without actually copying VyOS's implementation**.

---

# I'd make configuration transactional

This becomes particularly important when the firewall is remotely administered.

Something like:

```text
configure

set interfaces ethernet em0 address dhcp
set interfaces ethernet em1 address 10.10.120.1/23

set firewall ipv4 LAN rule 10 action accept

commit
```

The configuration engine should:

1. Parse
2. Validate
3. Resolve dependencies
4. Generate subsystem configuration
5. Validate generated configuration
6. Apply changes
7. Verify
8. Mark the transaction successful

And:

```text
commit-confirm 5
```

would be extremely useful.

---

# The firmware should be almost boring

I think this is actually one of the strongest aspects of your idea.

You don't want:

> "Here is a BSD computer where you can install whatever you want."

You want:

> **"This is a router/firewall. It does networking extremely well."**

So the installed filesystem might be surprisingly small:

```text
/bin
/sbin
/usr/bin
/usr/sbin
/etc
/var
/boot
```

plus your appliance components.

And the user-facing system becomes:

```text
                NetworkOS
                    │
        ┌───────────┼───────────┐
        │           │           │
       CLI         API          UI
        │           │           │
        └───────────┼───────────┘
                    │
             Configuration
                    │
        ┌───────────┼───────────┐
        │           │           │
       pf        Routing     Interfaces
```

That's a much more coherent product than trying to turn FreeBSD into another general-purpose appliance distribution.

---

# One thing I'd change from the typical BSD appliance model

I would make **your own management daemon** the centre of the system.

Something like:

```text
networkd
```

or:

```text
netconfigd
```

written in Go would actually make a lot of sense given your background.

It could own:

- configuration
- transactions
- API
- CLI backend
- service orchestration
- configuration validation
- audit trail
- state
- notifications

Then specialized components deal with the actual operating system:

```text
netconfigd
    │
    ├── pf backend
    ├── routing backend
    ├── interface backend
    ├── dhcp backend
    ├── dns backend
    ├── vpn backend
    └── system backend
```

That gives you a very clean boundary:

**Go = appliance control plane**

**FreeBSD = data plane / OS**

**pf = security enforcement**

---

## And I would make the image build completely deterministic

The ideal development workflow would eventually be:

```text
git checkout v1.8.0

./build.sh amd64
```

and get:

```text
networkos-1.8.0-amd64.img
networkos-1.8.0-amd64.sha256
networkos-1.8.0-amd64.sig
```

Then the appliance itself can expose:

```text
System
  Firmware
    Current:  1.7.3
    Available: 1.8.0

    [Install]
```

It downloads the signed image, verifies it, installs the new ZFS boot environment, and schedules the reboot.

That gets you very close to the **FortiGate appliance experience**, while retaining the transparency and hackability of BSD.

And I think **that combination—VyOS-style declarative network OS + pf + FreeBSD + ZFS boot environments + reproducible poudriere-built firmware—is a much more coherent direction than trying to make "OPNsense but different."**

**prompt**

What would it take to outline a project architecture for this

**response**

Quite a bit—but it is very tractable if you treat it as a **network operating system project**, not as a firewall GUI project.

I would start by producing an architecture document before writing much code. The architecture should answer six questions:

1. **What is the OS?**
2. **What is the configuration model?**
3. **How does configuration become running system state?**
4. **How do CLI/API/Web UI interact with it?**
5. **What are the networking/security subsystems?**
6. **How are firmware images built, upgraded, and recovered?**

Given what you've described, I'd outline it roughly like this.

---

# 1. Project definition

First establish the philosophy.

### Working concept

> A focused, open-source network operating system based on FreeBSD, using pf as its firewall/data-plane foundation, ZFS for storage and boot environments, and a declarative configuration system exposed consistently through CLI, REST API, and Web UI.

### Explicit non-goals

This is important.

It is **not**:

- a general-purpose FreeBSD distribution
- a virtualization platform
- a container platform
- a NAS
- a package-management environment for users
- a Linux router
- an OPNsense clone
- a FortiGate replacement with every security feature imaginable

The appliance does a relatively small number of things extremely well.

---

# 2. High-level architecture

I'd establish these layers:

```text
┌───────────────────────────────────────────────────────────┐
│                        User Layer                         │
│                                                           │
│              Web UI        CLI        REST API            │
└────────────────────────────┬──────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────┐
│                    Management Plane                        │
│                                                           │
│                   configuration daemon                    │
│                                                           │
│  schema │ validation │ transactions │ state │ audit       │
└────────────────────────────┬──────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────┐
│                     Service Layer                          │
│                                                           │
│ interfaces │ routing │ firewall │ NAT │ VPN │ DHCP       │
│ DNS │ NTP │ QoS │ HA │ monitoring │ certificates         │
└────────────────────────────┬──────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────┐
│                    FreeBSD Platform                        │
│                                                           │
│ kernel │ pf │ routing │ ifconfig │ netgraph │ drivers     │
│ IPsec │ ZFS │ crypto │ boot environments                  │
└───────────────────────────────────────────────────────────┘
```

I'd make this diagram the foundation of the whole project.

---

# 3. Repository architecture

I'd probably use a monorepo.

Something along these lines:

```text
networkos/
│
├── README.md
├── LICENSE
├── AGENTS.md
│
├── docs/
│   ├── architecture/
│   ├── configuration/
│   ├── networking/
│   ├── firewall/
│   ├── vpn/
│   ├── api/
│   ├── cli/
│   ├── ui/
│   └── operations/
│
├── cmd/
│   ├── netosd/
│   ├── netos/
│   └── netos-init/
│
├── internal/
│   ├── config/
│   ├── transaction/
│   ├── state/
│   ├── api/
│   ├── cli/
│   ├── system/
│   ├── interfaces/
│   ├── routing/
│   ├── firewall/
│   ├── nat/
│   ├── vpn/
│   ├── dhcp/
│   ├── dns/
│   ├── ntp/
│   ├── qos/
│   ├── ha/
│   ├── certificates/
│   └── audit/
│
├── api/
│   └── openapi.yaml
│
├── ui/
│
├── freebsd/
│   ├── kernel/
│   ├── patches/
│   └── configuration/
│
├── ports/
│   └── ...
│
├── build/
│   ├── poudriere/
│   ├── release/
│   ├── image/
│   └── signing/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── network/
│   └── hardware/
│
└── tools/
```

You don't necessarily need all of those directories initially, but this gives the project a sensible shape.

---

# 4. The configuration model is the most important part

I'd actually design this **before designing the CLI**.

For example:

```yaml
system:
  hostname: edge01
  timezone: America/Edmonton

interfaces:
  ethernet:
    em0:
      description: WAN
      address:
        - dhcp

    em1:
      description: LAN
      address:
        - 10.10.120.1/23

  vlan:
    vlan10:
      parent: em1
      vlan: 10
      address:
        - 10.10.10.1/24
```

Then:

```yaml
firewall:
  ipv4:
    LAN:
      default_action: drop

      rules:
        - id: 10
          action: accept
          protocol: tcp
          destination:
            port: 443
```

The important thing is that **this configuration model becomes the canonical API**.

The CLI shouldn't have its own configuration model.

The Web UI shouldn't have its own configuration model.

The REST API shouldn't have its own configuration model.

All three manipulate the same underlying model.

---

# 5. Configuration transaction engine

This deserves its own architectural component.

I'd make it roughly:

```text
                Candidate
                   │
                   ▼
              Parse schema
                   │
                   ▼
              Validation
                   │
                   ▼
            Dependency graph
                   │
                   ▼
             Configuration
                 plan
                   │
                   ▼
          Generate subsystem
             configuration
                   │
                   ▼
          Validate generated
              configuration
                   │
                   ▼
                 Apply
                   │
                   ▼
              Verify state
                   │
                   ▼
                Commit
```

And support:

```text
configure
set
delete
show
compare
validate
commit
commit-confirm
confirm
rollback
discard
save
```

This is probably the **single most important piece of architecture after the networking itself**.

---

# 6. Backend abstraction

I'd avoid allowing every subsystem to directly manipulate FreeBSD.

Instead:

```text
Configuration
      │
      ▼
Service Controller
      │
      ├── Interface Controller
      │
      ├── Routing Controller
      │
      ├── PF Controller
      │
      ├── NAT Controller
      │
      ├── VPN Controller
      │
      └── Service Controller
```

For example:

```go
type Firewall interface {
    Validate(cfg FirewallConfig) error
    Generate(cfg FirewallConfig) ([]byte, error)
    Apply(cfg FirewallConfig) error
    Status() (FirewallStatus, error)
}
```

Then the pf implementation becomes:

```text
Firewall
   │
   └── PF
       ├── rules
       ├── tables
       ├── NAT
       └── states
```

This makes testing much easier.

---

# 7. pf architecture

I'd give pf unusually strong architectural status.

Something like:

```text
firewall/
├── model/
│   ├── rule.go
│   ├── table.go
│   ├── nat.go
│   └── policy.go
│
├── validate/
├── compiler/
├── apply/
├── state/
└── pf/
    ├── generator.go
    ├── loader.go
    └── status.go
```

Your configuration:

```text
Firewall Rule
     ↓
internal model
     ↓
validation
     ↓
PF compiler
     ↓
pf.conf + anchors + tables
     ↓
pfctl
```

I'd strongly consider using **pf anchors** to allow different parts of the configuration to remain independently generated.

For example:

```text
netos/
├── system
├── interfaces
├── firewall
│   ├── input
│   ├── output
│   ├── forwarding
│   └── nat
└── vpn
```

becoming corresponding PF structures.

---

# 8. Routing architecture

Don't make routing an afterthought.

I'd separate:

```text
Routing model
      │
      ├── static routes
      ├── policy routing
      ├── routing tables
      └── dynamic routing
              │
              └── FRR
```

Potentially:

```text
OSPF
BGP
BFD
VRRP/CARP
```

But I'd make these **phase 2/3**, not initial requirements.

---

# 9. Interface architecture

This should understand the whole FreeBSD network hierarchy:

```text
Physical
   │
   ├── VLAN
   ├── LAG
   ├── Bridge
   └── Tunnel
```

Your configuration might therefore naturally look like:

```text
interfaces
├── ethernet
├── vlan
├── lag
├── bridge
├── loopback
├── wireguard
├── gre
└── ipsec
```

Then the firewall and routing layers reference interfaces by **logical identity**, not directly by `em0`.

That's important.

---

# 10. VPN architecture

I'd make VPN providers modular:

```text
vpn/
├── ipsec/
├── wireguard/
├── openvpn/
└── gre/
```

with a common conceptual model:

```text
VPN
├── local endpoint
├── remote endpoint
├── authentication
├── encryption
├── routing
└── firewall integration
```

But don't force every VPN implementation into an artificial common API where it doesn't fit.

---

# 11. API

I'd use REST/OpenAPI.

Something like:

```text
/api/v1/system
/api/v1/interfaces
/api/v1/routes
/api/v1/firewall
/api/v1/nat
/api/v1/vpn
/api/v1/dhcp
/api/v1/dns
/api/v1/certificates
/api/v1/status
/api/v1/monitoring
```

And importantly, expose **both configuration and operational state**.

For example:

```text
GET /api/v1/interfaces/em0
```

could return:

```json
{
  "name": "em0",
  "configured": true,
  "admin_state": "up",
  "link_state": "up",
  "speed": 10000,
  "addresses": ["203.0.113.10/24"],
  "rx_bytes": 123456789,
  "tx_bytes": 987654321
}
```

---

# 12. CLI

I'd build the CLI **from the API/configuration model**, rather than independently.

Potentially:

```text
netos

netos configure
netos show
netos commit
netos rollback
```

Interactive mode:

```text
netos# configure

netos(config)# set interfaces ethernet em1 address 10.10.120.1/23

netos(config)# set firewall ipv4 LAN default-action drop

netos(config)# commit
```

And noninteractive automation:

```bash
netos config set interfaces ethernet em1 address 10.10.120.1/23
netos config commit
```

---

# 13. Web UI

I'd deliberately make the Web UI **not the primary architecture**.

It should consume the same API users and automation consume.

```text
                  API
              /    |    \
             /     |     \
           CLI    UI    automation
```

That prevents the classic appliance problem where:

> "The GUI knows how to do it, but the API doesn't."

---

# 14. Firmware architecture

This is where your poudriere idea becomes a major architectural component.

I'd define:

```text
FreeBSD source
      │
      ├── kernel configuration
      ├── base system
      ├── ports
      └── NetOS source
             │
             ▼
          poudriere
             │
             ▼
          packages
             │
             ▼
        root filesystem
             │
             ▼
        release builder
             │
             ▼
      ZFS appliance image
             │
             ▼
       signed firmware
```

I'd make the build system capable of producing:

```text
netos-1.0.0-amd64.img
netos-1.0.0-arm64.img
netos-1.0.0-amd64.iso
netos-1.0.0-amd64.img.sha256
netos-1.0.0-amd64.img.sig
```

Eventually.

---

# 15. ZFS / boot architecture

I'd explicitly document the disk layout.

For example:

```text
GPT
├── EFI
├── swap
└── ZFS
     │
     ├── ROOT
     │    ├── 1.0.0
     │    └── 1.1.0
     │
     ├── DATA
     │    ├── config
     │    ├── certificates
     │    └── logs
     │
     └── ...
```

The exact layout needs careful design, but the conceptual separation is excellent.

Then firmware update becomes:

```text
Download
   ↓
Verify signature
   ↓
Create new boot environment
   ↓
Install OS
   ↓
Validate
   ↓
Mark next boot
   ↓
Reboot
```

And rollback:

```text
New OS
  ↓
boot
  ↓
health check
  ↓
FAIL
  ↓
previous boot environment
```

---

# 16. Recovery architecture

A network appliance **must** have a recovery strategy.

I'd define:

```text
Normal boot
    │
    ├── successful
    │
    └── failed
          ↓
       fallback
          ↓
     previous BE
          ↓
      recovery
```

Eventually you might want:

- console recovery
- factory reset
- firmware reinstall
- configuration backup/restore
- previous firmware selection
- rescue shell

---

# 17. Hardware abstraction

Don't let the application assume:

```text
em0
em1
em2
```

are always present.

Have hardware inventory:

```text
platform
├── system
├── cpu
├── memory
├── storage
├── pci
└── network
```

Then interface discovery can provide:

```text
NIC
├── PCI address
├── driver
├── MAC
├── interface
├── capabilities
└── link state
```

That becomes useful later for automated interface assignment.

---

# 18. Observability

I'd make this a first-class part of the architecture rather than an add-on.

```text
netosd
   │
   ├── structured logs
   ├── metrics
   ├── audit events
   └── system events
```

Then expose:

```text
/api/v1/metrics
/api/v1/logs
/api/v1/events
```

You could eventually make it very easy to export to Prometheus/Loki/etc.

---

# 19. Testing architecture

This project absolutely needs automated networking tests.

I'd have:

```text
tests/
├── unit/
├── config/
├── compiler/
├── API/
├── CLI/
├── integration/
│
├── networking/
│   ├── vlan
│   ├── routing
│   ├── nat
│   ├── firewall
│   └── vpn
│
└── boot/
    ├── install
    ├── upgrade
    └── rollback
```

And especially **virtual network topology tests**.

For example:

```text
       Client
       10.0.1.10
           │
           │
      ┌────▼────┐
      │ NetOS   │
      │         │
      └────┬────┘
           │
       10.0.2.10
           │
        Server
```

Then automatically test:

```text
client → server = allowed
client → server port 22 = denied
NAT works
DNS works
VPN works
routing works
```

This could become one of the most valuable pieces of the project.

---

# 20. Development phases

I would **not** start by implementing every firewall feature.

I'd make the first milestone almost ridiculously small.

### Phase 0 — Architecture

Produce:

- architecture document
- configuration schema
- repository layout
- API philosophy
- firmware architecture
- security model
- supported hardware assumptions

### Phase 1 — Bootable OS

Get:

```text
FreeBSD
+ ZFS
+ custom kernel
+ serial/console
+ SSH
```

booting as your own image.

### Phase 2 — Management daemon

```text
netosd
```

with:

- configuration
- persistence
- transactions
- logging
- CLI

### Phase 3 — Interfaces

Implement:

- Ethernet
- IP addressing
- VLAN
- routes

At this point:

```text
netos(config)# set interfaces ...
```

actually works.

### Phase 4 — pf

Implement:

- tables
- aliases
- rules
- state
- NAT

Now you have a genuine firewall.

### Phase 5 — API

Expose the complete configuration/state model.

### Phase 6 — Web UI

Build the UI on top of the API.

### Phase 7 — VPN

WireGuard → IPsec → OpenVPN.

### Phase 8 — Network services

DNS, DHCP, NTP, DDNS, etc.

### Phase 9 — Routing

OSPF/BGP/advanced routing.

### Phase 10 — HA / production

CARP, configuration synchronization, upgrade/rollback, hardware support, signed releases.

---

## One architectural decision I'd make very early

**Don't make the configuration file itself the API.**

Instead define an internal typed model:

```text
Configuration
   │
   ├── System
   ├── Interface
   ├── VLAN
   ├── Route
   ├── Firewall
   ├── NAT
   ├── VPN
   └── Services
```

Then you can have:

```text
              ┌─────────────┐
              │ Config Model│
              └──────┬──────┘
                     │
       ┌─────────────┼─────────────┐
       │             │             │
      CLI           REST           UI
       │             │             │
       └─────────────┼─────────────┘
                     │
              Transaction Engine
                     │
       ┌─────────────┼──────────────┐
       │             │              │
      pf          FreeBSD        Services
```

That gives you the **VyOS quality I think you're after** without tying the architecture to VyOS itself.

---

# The architecture document I'd actually create

I'd make a `docs/architecture.md` as the master document, with roughly:

```text
1. Vision
2. Goals
3. Non-goals
4. Design principles
5. System architecture
6. FreeBSD integration
7. Configuration model
8. Transaction engine
9. Interface subsystem
10. Routing subsystem
11. Firewall/pf subsystem
12. NAT subsystem
13. VPN subsystem
14. Network services
15. HA
16. Management API
17. CLI
18. Web UI
19. Logging/metrics
20. Security model
21. Storage/ZFS
22. Firmware/image build
23. Upgrade/rollback
24. Recovery
25. Hardware support
26. Testing
27. Release engineering
28. Development phases
```

And then I'd make **separate architecture decision records (ADRs)** for things like:

```text
ADR-001  FreeBSD as base OS
ADR-002  ZFS boot environments
ADR-003  pf as firewall engine
ADR-004  Go management daemon
ADR-005  Declarative configuration
ADR-006  REST/OpenAPI
ADR-007  Poudriere firmware builds
ADR-008  Signed firmware
ADR-009  Configuration persistence
ADR-010  FreeBSD vs OpenBSD pf
```

That would give you a solid blueprint before implementation starts.

**The next step I'd suggest is to actually write the architecture specification for this project together**, starting with the design principles and then drilling down into the configuration model and `netosd` architecture. Those two decisions will determine almost everything else.

**prompt**

Would a good name for the project be: netpf

**reponse**

Yes — **NetPF** is a pretty good name for this project, especially while you're defining the architecture.

I like it because it immediately communicates the two fundamental ideas:

- **Net** → network operating system/router
- **PF** → packet filtering/firewall foundation

And it's short enough to work well as both a project name and command:

```text
netpf
netpf configure
netpf show
netpf commit
```

### The one concern

**"NetPF" strongly suggests that the project is primarily a PF wrapper.**

Your actual concept is broader:

> A focused BSD network operating system whose firewall is based on PF.

That's a subtle but important distinction.

Your architecture is really:

```text
                    NetPF
                      │
        ┌─────────────┼─────────────┐
        │             │             │
    Interfaces     Routing         PF
        │             │             │
        └─────────────┼─────────────┘
                      │
             VPN / DHCP / DNS
                      │
             Management Plane
                      │
             FreeBSD + ZFS
```

So **NetPF works particularly well if PF is intended to be one of the defining characteristics of the product**, rather than merely the firewall implementation.

---

### I also like the visual simplicity

You could have:

```text
NetPF
Network Operating System
```

and commands:

```bash
netpf
netpf-cli
netpfd
```

Potentially:

```text
netpfd       management daemon
netpf        CLI
netpf-api    API
```

Although I'd probably just have the daemon be:

```text
netpfd
```

and the CLI:

```text
netpf
```

with the REST API served by `netpfd`.

---

### Compared with some alternatives

| Name          | Impression                                       |
| ------------- | ------------------------------------------------ |
| **NetPF**     | Network OS built around PF                       |
| **PFNet**     | PF-oriented networking toolkit                   |
| **BSDNet**    | Generic BSD networking                           |
| **NetBSD**    | Obviously problematic because of the existing OS |
| **PFOS**      | Firewall OS; narrower                            |
| **NetOS**     | Too generic                                      |
| **RouteBSD**  | Emphasizes routing                               |
| **FireBSD**   | Too firewall-centric / somewhat awkward          |
| **PacketBSD** | Sounds like a BSD distribution                   |
| **NetForge**  | More product-y, less descriptive                 |
| **NetGuard**  | Security-oriented, less networking-oriented      |

Of these, **NetPF is one of the better names if you want the technical identity to be obvious**.

### One thing I'd do before committing

I'd check the availability of:

```text
netpf.org
netpf.io
netpf.dev
netpf.systems
netpf.net
github.com/.../netpf
```

and, importantly, whether **NetPF/netpf is already being used by an existing networking project or product**.

If it's clear, I'd be quite comfortable using **NetPF** as the working project name. It also leaves room for the project's identity to be:

> **NetPF — a focused, declarative BSD network operating system powered by PF.**

That description fits the architecture you've been outlining unusually well.
