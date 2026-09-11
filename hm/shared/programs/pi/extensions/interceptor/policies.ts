import type { PermissionPolicy } from "./index.ts";

/** Restricts agentic review and commit workflows to repository inspection. */
export const GIT_INSPECTION_BASH_POLICY: PermissionPolicy = {
  rules: [
    {
      bash: "*",
      action: "deny",
      reason: "Only read-only Git and rg inspection is allowed",
    },
    { bash: "git status*", action: "allow" },
    { bash: "git diff*", action: "allow" },
    { bash: "git log*", action: "allow" },
    { bash: "git show*", action: "allow" },
    { bash: "rg --no-config*", action: "allow" },
    {
      bash: "*>*",
      action: "deny",
      reason: "Shell output redirection is not allowed",
    },
    {
      bash: "git *--ext-diff*",
      action: "deny",
      reason: "External Git diff commands are not allowed",
    },
    {
      bash: "git *--textconv*",
      action: "deny",
      reason: "Git text conversion commands are not allowed",
    },
    {
      bash: "git *--output*",
      action: "deny",
      reason: "Git output files are not allowed",
    },
    {
      bash: "rg *--pre*",
      action: "deny",
      reason: "rg preprocessors are not allowed",
    },
  ],
};
