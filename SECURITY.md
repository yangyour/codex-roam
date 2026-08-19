# Security Policy

CodexRoam exposes a local coding agent to private network clients. Treat the
bridge token and EasyTier network secret like passwords.

Security fixes are prioritized for the default `main` branch. This is a
self-hosted project, not a public SaaS service, and old releases are not
guaranteed long-term support.

- Never commit `.codex-console-token` or `.codex-roam.local.json`.
- Use a unique, non-empty EasyTier network secret for public deployments.
- Do not expose port `4174` directly to the public internet.
- Review command approval requests before accepting them from the phone.

Report security issues privately to the repository owner through the contact
method on the GitHub profile instead of opening a public issue. Include the
affected commit or version, impact, and minimal reproduction steps, but never
include real credentials, session files, private address inventories, or full
logs. Please allow reasonable time for validation and remediation before public
disclosure.

See [SECURITY.zh-CN.md](SECURITY.zh-CN.md) for the Chinese version.
