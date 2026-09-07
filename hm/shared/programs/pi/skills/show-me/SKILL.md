---
name: show-me
description: Help the user understand the current topic visually with concise diagrams, code-shape sketches, and focused HTML artifacts.
metadata:
  source: "https://github.com/humanlayer/skills"
  commit: "3c2629142c5d437428269b1b722b08c0b87f574d"
---

# Show me

Pick the smallest visual that answers the user's current question. Skip the preamble and keep supporting prose brief.

## Choose a view

- For logic, runtime flow, UI structure, file responsibilities, interactions, or a focused change, read [Text views](text-views.md). Use pseudocode, a shallow tree, Mermaid, or a diff as appropriate.
- For visual UI, layout, state comparisons, or a concept too dense for a text diagram, read [HTML artifacts](html.md).

Keep only the calls, files, props, states, and boundaries needed to explain the point. Preserve important ownership and ordering; label proposed or simplified views so they are not mistaken for the current implementation.

Place each visual next to the short text it supports. Use several views only when each answers a distinct part of the question; avoid turning a focused explanation into a feature tour.
