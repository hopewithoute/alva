Status: ready-for-agent

# PRD - Alva Collections on LiveView Streams

Alva Collections are server-owned reactive lists exposed through a `collection` DSL and implemented as thin mappings onto Phoenix LiveView streams plus LiveVue stream diffs. Collections replace the current props-diff workaround for route-owned lists: source data is loaded through an explicit source event, realtime operations map to native stream primitives, Vue renders `@streams.*` props, and plain assigns remain for non-collection props.

This work follows ADR 0003 and should lean on LiveView semantics rather than inventing a separate list reconciliation engine.
