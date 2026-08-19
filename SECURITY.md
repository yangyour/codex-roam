# Security Policy

CodexRoam exposes a local coding agent to private network clients. Treat the
bridge token and EasyTier network secret like passwords.

- Never commit `.codex-console-token` or `.codex-roam.local.json`.
- Use a unique, non-empty EasyTier network secret for public deployments.
- Do not expose port `4174` directly to the public internet.
- Review command approval requests before accepting them from the phone.

Report security issues privately to the repository owner instead of opening a
public issue with credentials or exploit details.
