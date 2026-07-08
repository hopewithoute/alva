# ADR 0010: Retain Alva.Result for LiveView Abstraction

## Status
Accepted

## Context
During an architecture review, it was suggested that `Alva.Result` is a shallow module that merely wraps standard `Phoenix.LiveView` socket operations (`stream_insert`, `assign`, `push_navigate`) behind a proprietary DSL (`strategy:`), and could therefore be deleted to improve locality.

However, the primary design goal of Alva is to ensure developers do not need to write Phoenix handlers inside their LiveView files. We want all domain logic and side-effects to be handled declaratively through Ash. 

## Decision
We will **retain `Alva.Result`** as a core abstraction layer. Even if its interface is thin today, it serves as a critical **seam** that shields the LiveView process from raw domain execution results. It translates Ash occurrences into LiveView primitives without forcing the developer to write boilerplate `handle_info` or `handle_event` callbacks.

## Consequences
- Developers continue to configure `strategy:` DSLs rather than writing LiveView handlers.
- The boundary between Ash and LiveView remains intact.
- Future architecture reviews should not suggest removing `Alva.Result` based on the "deletion test," as its value lies in enforcing the declarative developer experience, rather than complex internal logic.
