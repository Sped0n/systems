import type { Hooks, PluginInput } from "@opencode-ai/plugin";

const cache = new Map<string, string>();

const parse = (value: unknown) => {
  const opts =
    value && typeof value === "object" && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {};
  const providers = Array.isArray(opts.providers)
    ? opts.providers
        .filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter(Boolean)
    : [];
  return { providers: providers.length ? providers : ["__PROVIDER_ID__"] };
};

const key = (input: { sessionID: string; message: { id: string } }) =>
  `${input.sessionID}:${input.message.id}`;

const match = (
  input: {
    model: {
      providerID: string;
      id: string;
      name: string;
      api: { id: string };
    };
  },
  providers: string[],
) => {
  if (!providers.includes(input.model.providerID)) return false;
  return [input.model.id, input.model.name, input.model.api.id].some((item) =>
    item.toLowerCase().includes("gpt"),
  );
};

const pick = (options: Record<string, unknown>) => {
  const value = options.prompt_cache_key ?? options.promptCacheKey;
  if (typeof value !== "string" || !value) return;
  return value;
};

const plugin = {
  id: "gpt-cache-headers",
  async server(_input: PluginInput, value?: unknown): Promise<Hooks> {
    const opts = parse(value);

    return {
      "chat.params": async (input, output) => {
        if (!match(input, opts.providers)) return;
        const value = pick(output.options);
        if (!value) return;
        cache.set(key(input), value);
      },
      "chat.headers": async (input, output) => {
        if (!match(input, opts.providers)) return;
        const id = key(input);
        const value = cache.get(id);
        cache.delete(id);
        if (!value) return;
        output.headers.conversation_id = value;
        output.headers.session_id = value;
      },
    };
  },
};

export default plugin;
