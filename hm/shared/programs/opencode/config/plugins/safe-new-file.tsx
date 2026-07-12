import { lstat, mkdir } from "node:fs/promises"
import { dirname, isAbsolute, relative, resolve } from "node:path"

export async function safeNewFile(root: string, input: string) {
  const file = resolve(root, input)
  const local = relative(root, file)
  if (isAbsolute(input) || local === ".." || local.startsWith(`..${process.platform === "win32" ? "\\" : "/"}`)) {
    throw new Error("Output paths must stay inside the project")
  }

  let current = root
  for (const part of relative(root, dirname(file)).split(/[\\/]/).filter(Boolean)) {
    current = resolve(current, part)
    try {
      if ((await lstat(current)).isSymbolicLink()) throw new Error(`Output directory is a symbolic link: ${current}`)
    } catch (cause) {
      if ((cause as NodeJS.ErrnoException).code !== "ENOENT") throw cause
    }
  }

  await mkdir(dirname(file), { recursive: true })
  return file
}
