---
status: accepted
---

# Use PF as the firewall foundation

PF is a defining NetPF subsystem and the preferred firewall foundation, rather than an incidental implementation hidden behind an appliance GUI. The control plane should expose a usable policy model and manage PF through a backend, while retaining native BSD tools for expert diagnostics. This records the preference for PF expressed in the research; it does not choose a BSD family or resolve the differences between OpenBSD PF and FreeBSD's PF.
