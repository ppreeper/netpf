---
status: proposed
---

# Use one declarative configuration model

The proposed management architecture uses one typed desired-state model shared by the CLI, REST API, and Web UI. Changes are staged, validated as a whole, translated by subsystem backends, applied, and verified before they are committed; a confirmed commit with automatic rollback is recommended for remote management. This adopts the configuration philosophy favored in the research without yet fixing the schema, persistence format, transaction guarantees, daemon language, or API contract.
