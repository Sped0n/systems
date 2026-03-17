import type { Plugin } from "@opencode-ai/plugin";

const PROVIDER = "ianepo";
const MARKER = "env:IANEPO_API_KEY";

export const IAnepOPlugin: Plugin = async (ctx) => {
  const key = process.env.IANEPO_API_KEY?.trim();
  if (key) {
    await ctx.client.auth
      .set({
        path: {
          id: PROVIDER,
        },
        body: {
          type: "api",
          key: MARKER,
        },
      })
      .catch(() => {});
  }
  return {
    auth: {
      provider: PROVIDER,
      methods: [
        {
          type: "api",
          label: "env",
          async authorize() {
            const key = process.env.IANEPO_API_KEY?.trim();
            if (!key) return { type: "failed" };
            return {
              type: "success",
              key: MARKER,
            };
          },
        },
      ],
      async loader(getAuth) {
        const auth = await getAuth();
        const key = process.env.IANEPO_API_KEY?.trim();
        if (auth.type !== "api") return {};
        if (!key) throw new Error("IANEPO_API_KEY is not set");
        return {
          apiKey: key,
          async fetch(input, init) {
            const opts = { ...(init ?? {}) };
            if (opts.method === "POST" && typeof opts.body === "string") {
              try {
                const body = JSON.parse(opts.body);
                const url =
                  input instanceof URL ? input.href : input.toString();
                if (url.endsWith("/responses")) {
                  delete body.max_output_tokens;
                }
                opts.body = JSON.stringify(body);
              } catch {}
            }
            return fetch(input, {
              ...opts,
              // @ts-expect-error
              timeout: false,
            });
          },
        };
      },
    },
  };
};
