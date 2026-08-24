# Exit alias

Registers `/exit` as a standard extension-command alias for Pi's built-in
`/quit`. Both commands use the description `Quit pi`; Pi provides autocomplete
and displays its normal extension-command source label for `/exit`.

The command calls Pi's graceful shutdown path, which waits for active work to
become idle before exiting.
