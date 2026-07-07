## Security

Security is the highest priority — it overrides speed, convenience, and code brevity whenever they conflict.

- Never introduce a known-insecure pattern (e.g. string-concatenated SQL, unsanitized input in shell/HTML/eval contexts, hardcoded secrets, disabled TLS/cert checks, weak crypto) even if the user's request doesn't mention security.
- If a requested change would weaken an existing security control (auth check, input validation, permission scope, encryption), implement it but flag the tradeoff explicitly and ask for confirmation before proceeding — don't silently comply.
- If you notice a security issue while working on something else (incidental discovery), call it out immediately rather than staying silent because it's out of scope.
- When a secure and an insecure approach both satisfy the task, default to the secure one even if it takes more code or more tokens.
- Treat this as standing authorization to raise security concerns unprompted; it does not authorize refusing legitimate work — flag and explain, then follow the user's decision unless it crosses into actual harm.

## Response Style and Verbosity

- Be extremely succinct and concise.
- Avoid conversational filler, introductory remarks, or summarizing code unless explicitly requested.


## Document templates

When creating or substantially restructuring a standalone documentation file (architecture/design doc, developer onboarding doc, PRD, etc.), start from the matching template in `~/.claude/doc_templates/` rather than inventing a structure from scratch.

### Picking a template

- DESIGN_template.md - architecture/system design docs: component decomposition, context diagrams, component interconnection, per-component communication. Use for any doc describing how a system's pieces fit together.
- DEVELOPMENT_template.md - developer-facing repo docs: toolchain setup, local dev loop, test environment, how-to guides, troubleshooting. Use for onboarding/README/CONTRIBUTING-style docs.
- PRODUCT_REQUIREMENT_DOCUMENT_template.md - PRDs: executive summary plus overview/requirements sections.
- generic_template.md - fallback for any other standalone doc that doesn't fit the above (short notes, one-off write-ups).

If unsure which fits, ask rather than guessing.

## How to use a template

- Read the template fully before writing - it encodes section order and intent (e.g. DESIGN_template's "Reading this document" section explains its three organizational levels: introduction, overview, per-component sections).
- Copy its structure into the new document; replace `DOCUMENT_NAME` and placeholder headings with real content.
- Keep the `Introduction` sections (Purpose, Vocabulary, References) - common across all templates.
- Sections marked optional in the template's HTML comments can be dropped if not applicable; don't drop required structural sections.
- Do not invent a new top-level structure for a doc type a template already covers - extend the template instead.


## Documentation Guidelines

On changes, update relevant docs:

- README.md - end-user guide (install, usage, troubleshooting, core make targets). Update when user-facing workflows change.
- docs/DEVELOPMENT.md - maintainer guide. Update project structure tree, Where to Look table, improvement/review make targets, build instructions.
- docs/ARCHITECTURE.md - system architecture reference. Update diagrams/tables when architecture changes.
- docs/templates/ARCHITECTURE_template.md - template for ARCHITECTURE.md.
- docs/templates/DEVELOPMENT_template.md - template for DEVELOPMENT.md.
- docs/templates/generic_template.md - default template for other .md files.

### Style

- No em-dash '—'.
- No ASCII tree chars. Bullet lists only.
- Table rows sorted alphabetically.
- No ambiguous pronouns ('it', 'this', 'they') opening sentences. Restate subject.
- H1 for title only. No heading deeper than H4.
- Subsection of single parent item = one level lower than parent.
- Numbered lists only when fenced code blocks sit between steps; else bullets.
- Single commands inline as backticks. Fenced code blocks only for multi-line or when lang hint clarifies.

#### Topic structure

- Self-contained topics. Each answers one question on one subject for one purpose.
- Link to overviews for background.
- Repeat context inside topic where needed for orientation.
- Meaningful heading per topic.

#### Sentences + paragraphs

- Short declarative/imperative sentences. Active voice, present tense, concrete words. Consistent terms.
- One idea per paragraph. Topic sentence first. 3–5 sentences. ≤75 words.

#### Conciseness

- No flowery language, buzzwords, unsupported claims.
- No intro text that repeats headings.
- Don't over-cut: avoid choppy/confusing/incomplete output.
- For order-independent topics: link or repeat context as needed.
- Prefer tables/charts/figures over prose where possible.
- Prefer bullets over 2-column tables.

#### Headings

- Short precise abstract of section content (headings show in search/bookmarks out of context).
- No leading article or lowercase technical term.
- Don't repeat parent heading text in subheadings.
- Qualifiers (overview/task/reference) applied consistently if used.

#### Bullet lists

- Break long paragraphs into bullets.
- ≤9 items per list.
- Concise phrases over full sentences.
- Multi-sentence item: first sentence = summary.

#### Jump lists

- Clickable topic list for navigation. Use for:
  - Chapter/section contents.
  - Procedures (inc. long complex tasks).
  - Related cross-referenced topics.
- Briefly explain each link. Bold key terms.

### Terminology

- "authenticate" not "login".
- "request" not "call".
- Prefer "you" over "we".

### Diagrams

- Mermaid only.
- Layout: outside = left, inside (described component) = right.
