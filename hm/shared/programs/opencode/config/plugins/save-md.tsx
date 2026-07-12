import { writeFile } from "node:fs/promises"

import { safeNewFile } from "./safe-new-file.tsx"

import type { Part } from "@opencode-ai/sdk/v2"
import type { TuiPluginModule } from "@opencode-ai/plugin/tui"

function text(parts: readonly Part[]) {
  return parts
    .filter((part): part is Extract<Part, { type: "text" }> => part.type === "text")
    .map((part) => part.text)
    .join("\n\n")
    .trim()
}

const plugin: TuiPluginModule = {
  id: "spedon.save-md",
  tui: async (api) => {
    api.keymap.registerLayer({
      commands: [{
        namespace: "palette",
        name: "save-md.open",
        title: "Save latest response as Markdown",
        desc: "Save Markdown: write the latest assistant text to a new project file",
        category: "Plugin",
        slashName: "save-md",
        enabled: () => api.route.current.name === "session",
        run: () => {
          api.ui.dialog.replace(() =>
            api.ui.DialogPrompt({
              title: "Save Markdown",
              placeholder: "path/to/response.md",
              onConfirm: (input) => {
                api.ui.dialog.clear()
                void (async () => {
                  const route = api.route.current
                  const id = route.name === "session" ? route.params.sessionID : undefined
                  if (!id) throw new Error("Open a session before using /save-md")

                  const name = input.trim()
                  if (!name) throw new Error("Enter a file name")

                  const messages = api.state.session.messages(id)
                  const assistant = [...messages].reverse().find((message) => message.role === "assistant")
                  if (!assistant) throw new Error("No assistant response to save")

                  const markdown = text(api.state.part(assistant.id))
                  if (!markdown) throw new Error("The latest assistant response has no text")

                  const file = await safeNewFile(
                    api.state.path.directory,
                    name.endsWith(".md") ? name : `${name}.md`,
                  )
                  await writeFile(file, `${markdown}\n`, { encoding: "utf8", flag: "wx" })
                  api.ui.toast({ variant: "success", message: `Saved Markdown to ${file}` })
                })().catch((error) => {
                  api.ui.toast({
                    variant: "error",
                    message: error instanceof Error ? error.message : String(error),
                  })
                })
              },
            }),
          )
        },
      }],
      bindings: [],
    })
  },
}

export default plugin
