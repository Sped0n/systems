# UI

The footer displays Pi's statistics and extension statuses. It places the
session-control marker beside the working directory and `(fast)` beside the model
name. The model label omits the provider prefix.

The Control and OpenAI extensions publish values through status keys. This
extension renders the footer.

The input box border uses the theme's accent color at every reasoning effort
level. Bash mode keeps its own border color.

During each turn, the working message displays a random phrase from the list in
`whimsical.ts`. The default message returns when the turn ends.
