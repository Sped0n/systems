# HTML artifacts

Use one focused HTML file for visual UI, layout, state comparisons, or a concept too dense for a text diagram. Choose a diagram, infographic, or short slide deck according to the point being explained.

- Match the product's colors, typography, spacing, and components when that context is available.
- Use real labels and available data; label illustrative values rather than presenting invented data as facts.
- Support desktop and mobile layouts, readable contrast, and keyboard access for interactive elements.
- Keep the artifact self-contained when practical. Avoid external dependencies that do not help explain the topic.
- Write to a task-appropriate path such as `show-me-session-flow.html`, respecting read-only scope and avoiding overwriting unrelated files. If writes are not authorized, provide an inline text view instead.
- Inspect the generated file and, when browser tooling is available, check its rendered layout and interactions.
- Open it with the platform's supported launcher when available, such as `open path/to/show-me-session-flow.html` on macOS or `xdg-open path/to/show-me-session-flow.html` on Linux. Otherwise provide the file path and state that it was not opened.

Keep the artifact focused on the current question, not a full application or a general presentation template.
