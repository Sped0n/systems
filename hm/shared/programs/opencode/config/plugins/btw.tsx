/** @jsxImportSource @opentui/solid */
import { SyntaxStyle } from "@opentui/core"
import type { Part } from "@opencode-ai/sdk/v2"
import type { TuiPluginModule, TuiThemeCurrent } from "@opencode-ai/plugin/tui"
import { createSignal } from "solid-js"
import { spawnSync } from "node:child_process"
import { writeFile } from "node:fs/promises"
import { join } from "node:path"

import { safeNewFile } from "./safe-new-file.tsx"

function text(parts: readonly Part[]) {
  return parts
    .filter((part): part is Extract<Part, { type: "text" }> => part.type === "text")
    .map((part) => part.text)
    .join("\n\n")
    .trim()
}

function syntaxStyle(theme: TuiThemeCurrent) {
  return SyntaxStyle.fromStyles({
    "markup.heading": { fg: theme.markdownHeading, bold: true },
    "markup.strong": { fg: theme.markdownStrong, bold: true },
    "markup.italic": { fg: theme.markdownEmph, italic: true },
    "markup.link": { fg: theme.markdownLink },
    "markup.raw": { fg: theme.markdownCode },
    "markup.raw.block": { fg: theme.markdownCodeBlock },
    comment: { fg: theme.syntaxComment },
    keyword: { fg: theme.syntaxKeyword },
    function: { fg: theme.syntaxFunction },
    variable: { fg: theme.syntaxVariable },
    string: { fg: theme.syntaxString },
    number: { fg: theme.syntaxNumber },
    type: { fg: theme.syntaxType },
    operator: { fg: theme.syntaxOperator },
    punctuation: { fg: theme.syntaxPunctuation },
  })
}

function timestamp() {
  return new Date().toISOString().replace(/[-:.]/g, "")
}

function copy(text: string) {
  const command = process.platform === "darwin" ? "pbcopy" : process.env.WAYLAND_DISPLAY ? "wl-copy" : undefined
  if (command) {
    const result = spawnSync(command, { input: text, encoding: "utf8" })
    if (!result.error) {
      if (result.status !== 0) throw new Error(result.stderr.trim() || `${command} exited with status ${result.status}`)
      return
    }
    if ((result.error as NodeJS.ErrnoException).code !== "ENOENT") throw result.error
  }

  if (!process.stdout.isTTY) throw new Error("No native clipboard tool or OSC 52 terminal available")
  const sequence = `\x1b]52;c;${Buffer.from(text).toString("base64")}\x07`
  process.stdout.write(process.env.TMUX || process.env.STY ? `\x1bPtmux;\x1b${sequence}\x1b\\` : sequence)
}

const plugin: TuiPluginModule = {
  id: "spedon.btw",
  tui: async (api) => {
    type Fork = { id: number; directory: string; sessionID?: string; cleanup?: Promise<void> }

    let currentAnswer = ""
    let resultVisible = false
    let requestID = 0
    let activeFork: Fork | undefined

    const closeFork = (fork: Fork | undefined) => {
      if (!fork?.sessionID) return Promise.resolve()
      if (!fork.cleanup) {
        fork.cleanup = (async () => {
          await api.client.session.abort({ sessionID: fork.sessionID!, directory: fork.directory }).catch(() => {})
          await api.client.session.delete({ sessionID: fork.sessionID!, directory: fork.directory })
        })()
      }
      return fork.cleanup
    }

    api.lifecycle.onDispose(() => {
      void closeFork(activeFork).catch(() => {})
    })

    api.keymap.registerLayer({
      priority: 1000,
      enabled: () => resultVisible && api.ui.dialog.open,
      commands: [
        {
          name: "btw.copy",
          run: () => {
            if (!currentAnswer) return
            try {
              copy(currentAnswer)
              api.ui.toast({ variant: "success", message: "Copied BTW answer" })
            } catch (cause) {
              api.ui.toast({ variant: "error", message: cause instanceof Error ? cause.message : String(cause) })
            }
          },
        },
        {
          name: "btw.save",
          run: () => {
            if (!currentAnswer) return
            void (async () => {
              const file = await safeNewFile(api.state.path.directory, join(".opencode", "btw", `${timestamp()}.md`))
              await writeFile(file, `${currentAnswer}\n`, { encoding: "utf8", flag: "wx" })
              api.ui.toast({ variant: "success", message: `Saved BTW answer to ${file}` })
            })().catch((cause) => {
              api.ui.toast({ variant: "error", message: cause instanceof Error ? cause.message : String(cause) })
            })
          },
        },
      ],
      bindings: [
        { key: "y", cmd: "btw.copy" },
        { key: "s", cmd: "btw.save" },
      ],
    })

    const showAnswer = (mainSessionID: string, question: string) => {
      let finish: (answer: string, error?: boolean) => void = () => {}
      const fork: Fork = { id: ++requestID, directory: api.state.path.directory }
      void closeFork(activeFork).catch(() => {})
      activeFork = fork
      currentAnswer = ""
      resultVisible = true

      api.ui.dialog.replace(() => {
        const [answer, setAnswer] = createSignal("")
        const [error, setError] = createSignal(false)
        // OpenCode anchors dialogs at one-quarter screen height. A half-height
        // panel is therefore vertically centered; longer answers scroll.
        const height = Math.max(6, Math.floor(api.renderer.height / 2) - 4)
        const markdownStyle = syntaxStyle(api.theme.current)
        finish = (value, failed = false) => {
          if (activeFork !== fork) return
          currentAnswer = failed ? "" : value
          setAnswer(value)
          setError(failed)
        }

        return (
          <box paddingLeft={2} paddingRight={2} paddingBottom={1} flexDirection="column" gap={1}>
            <text fg={api.theme.current.text}>
              <b>BTW</b> <span fg={api.theme.current.textMuted}>{question}</span>
            </text>
            <scrollbox
              height={height}
              scrollY
              stickyScroll
              stickyStart="top"
              verticalScrollbarOptions={{ visible: true }}
            >
              {answer() ? (
                error() ? (
                  <text fg={api.theme.current.error}>{answer()}</text>
                ) : (
                  <markdown
                    content={answer()}
                    syntaxStyle={markdownStyle}
                    fg={api.theme.current.markdownText}
                  />
                )
              ) : (
                <text fg={api.theme.current.textMuted}>Answering...</text>
              )}
            </scrollbox>
            <text fg={api.theme.current.textMuted}>y copy all · s save · esc dismiss</text>
          </box>
        )
      }, () => {
        if (activeFork === fork) activeFork = undefined
        resultVisible = false
        currentAnswer = ""
        void closeFork(fork).catch(() => {})
      })
      api.ui.dialog.setSize("xlarge")

      void (async () => {
        const response = await api.client.session.fork({
          sessionID: mainSessionID,
          directory: fork.directory,
        })
        if (!response.data) throw new Error("Failed to fork the current session")
        fork.sessionID = response.data.id
        if (activeFork !== fork) {
          await closeFork(fork)
          return
        }

        try {
          const response = await api.client.session.prompt({
            sessionID: fork.sessionID,
            directory: fork.directory,
            agent: "btw",
            system:
              "This is a one-off side question. Answer directly from the existing conversation context. Do not use tools, take actions, or promise follow-up work. If the context does not contain the answer, say so.",
            parts: [{ type: "text", text: question }],
          })
          if (!response.data) throw new Error("The side question returned no response")
          finish(text(response.data.parts) || "The side question returned no text.")
        } finally {
          await closeFork(fork).catch((cause) => {
            api.ui.toast({
              variant: "error",
              message: `BTW answered, but fork cleanup failed: ${cause instanceof Error ? cause.message : String(cause)}`,
            })
          })
        }
      })().catch((cause) => {
        finish(cause instanceof Error ? cause.message : String(cause), true)
      })
    }

    api.keymap.registerLayer({
      commands: [
        {
          namespace: "palette",
          name: "btw.open",
          title: "BTW: Ask a quick side question",
          desc: "Answer once from current context without changing the conversation",
          category: "Plugin",
          slashName: "btw",
          enabled: () => api.route.current.name === "session",
          run: () => {
            api.ui.dialog.replace(() =>
              api.ui.DialogPrompt({
                title: "BTW",
                placeholder: "Ask a quick side question",
                onConfirm: (input) => {
                  const route = api.route.current
                  const mainSessionID = route.name === "session" ? route.params.sessionID : undefined
                  if (!mainSessionID) {
                    api.ui.toast({ variant: "error", message: "Open a session before using /btw" })
                    return
                  }

                  const question = input.trim()
                  if (!question) return
                  showAnswer(mainSessionID, question)
                },
              }),
            )
          },
        },
      ],
      bindings: [],
    })
  },
}

export default plugin
