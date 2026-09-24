# Agentic AI for Biomedical Data Science

A CCB workshop on building **structured agentic workflows** for biomedical data
analysis — and on doing it reproducibly, safely, and with a human in the loop.

Core for Computational Biomedicine (CCB) · Department of Biomedical Informatics (DBMI) · Harvard Medical School

---

## Format

The workshop runs in two halves, roughly 45 minutes each.

| | Session | Presenters |
|---|---|---|
| **1** | **Concepts & framework** — slide presentation | Grey Kuling, Anthony Christidis |
| **2** | **Demo** — reproducing the statistical analysis of a published paper with an agentic workflow | Alex Pickering |

## Repository layout

```
slides/   CCB_Intro.pdf                             — introduction to the CCB and its services
          Agentic-AI-slides.pdf                     — session 1 presentation
          Reproducing-a-published-paper-slides.pdf  — session 2 demo slides
demo/     session 2 demo: a Mendelian randomization paper reproduced with Claude Code
          (code, prompts, outputs, and the interactive deck in demo/workshop/)
```

---

## What the slides cover

**Foundations — what you actually control**

The model is fixed; the *harness* around it is yours. Instructions, files,
tools, and guardrails are the program you write. Context is the finite
resource: a bigger window is a bigger haystack, not a better search.

**Building blocks**

- **Tool calling** — the agent requests an action, the result becomes new
  context. It stops talking about DESeq2 and runs DESeq2.
- **MCP** — one protocol, many tools (PubMed, ClinicalTrials.gov, Open
  Targets, a SLURM cluster). Plug in once instead of custom wiring each one.
- **Skills** — your lab's protocols written down once as `SKILL.md`, opened
  only when relevant (progressive disclosure).
- **Sub-agents** — delegate a task to a fresh context window. File reads, dead
  ends and retries stay there; only the summary comes back.

**The four-phase framework**

```
1. Research  →  2. Plan  →  3. Execute  →  4. Reflect
 RESEARCH.md     PLAN.md    scripts+figures   REPORT.md
        ←— human review at every step: send it back one phase —←
```

Configuration splits the same way: `CLAUDE.md` and `.claude/skills/` hold the
general setup (tooling, standards, rules) and are written once; `RESEARCH.md`,
`PLAN.md` and `REPORT.md` are generated per analysis. Planning is the hard
part and worth a frontier model — once the plan is clear and approved, a
cheaper model can execute it.

**What can go wrong**

*Completion ≠ correctness.* A plan can hide real complexity, an agent can
delete real files, a result can be a hallucination. Don't trust it blindly.

**Working with sensitive data**

Demo and test with de-identified or synthetic data; keep real patient data on
approved, secure systems; ask your data-security office when unsure. The deck
maps the HMS data levels (1–5) to which tools are permitted — Level 4 requires
approval via `hms-it-ai@hms.harvard.edu`, and Level 5 has no approved AI tool.
Treat the agent like any new team member: need-to-know access only.

---

## Takeaways

1. A structured agentic workflow beats clever prompt engineering.
2. Separate Research and Plan from Execution.
3. Use `CLAUDE.md` and `SKILL.md` for general configuration.
4. Use `RESEARCH.md`, `PLAN.md` and `REPORT.md` for their phases.
5. Keep a **human in the loop** at every stage.

## Further reading

Slides 26–27 carry the full reading list — Anthropic's engineering writeups
(building effective agents, context engineering, writing tools, multi-agent
systems), the Claude Code documentation, agents for biomedical research
(Biomni, The Virtual Lab, CellAgent, BixBench, and ToolUniverse/TxAgent from
the Zitnik Lab here at DBMI), and references on reproducibility and
environments.

Starting points:

- [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)
- [Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude Code documentation](https://docs.claude.com/en/docs/claude-code/overview)
- [Model Context Protocol](https://modelcontextprotocol.io)

---

*September 24, 2026 · Harvard Medical School, Blavatnik Institute*
