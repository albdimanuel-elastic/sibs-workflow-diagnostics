# SIBS workflow diagnostics

Elastic Security workflow for a host at or above 90% CPU. An alert starts an Agent Builder agent that decides whether Elastic Defend is the cause, requests Fleet diagnostics only when it is, and opens one Security case.

Setup, Kibana objects, and the two demo scenarios are in [HOW-TO.md](HOW-TO.md).

Copy [`.env.example`](.env.example) to `.env` and fill in your Kibana URL, Elasticsearch URL, API key, and the SSH target for the agent host. `.env`, SSH keys, and local Elastic config stay out of git.
