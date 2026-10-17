# Project Agent Instructions

## Source of truth and scope

- Read `design.md` before making design or implementation decisions. It is the source of truth for the game's high-level design, intended behavior, architecture constraints, and priorities.
- `design.md` has not necessarily been created yet. If it is missing, do not invent game-specific requirements or silently establish major design decisions. Ask for the missing design or limit work to clearly requested, design-independent setup.
- Keep this file focused on engineering workflow and quality practices. Put game-specific decisions in `design.md`.
- Before substantial work, inspect the existing project and Git status. Preserve established conventions unless there is a clear reason to change them.
- If instructions conflict, explain the conflict and follow the user's latest explicit direction unless it would cause data loss or make the project inconsistent.

## Agent workflow

1. **Understand first.** Inspect relevant files, `project.godot`, scenes, scripts, assets, project settings, existing tests, and `git status` before editing. Read the smallest useful set of files, then expand as needed.
2. **Plan proportionally.** For a small change, state a brief plan. For a multi-file or architectural change, outline the intended edits and verification steps before implementation.
3. **Make focused changes.** Prefer the smallest complete change that solves the requested problem. Avoid unrelated refactors, broad rewrites, premature abstractions, and speculative features.
4. **Respect existing patterns.** Reuse established scene structure, script conventions, signals, resources, and naming. Do not introduce dependencies or plugins without explaining why they are needed.
5. **Keep changes reviewable.** Avoid mixing unrelated changes. Do not overwrite user work, regenerate large sets of files unnecessarily, or edit generated/imported artifacts directly when the source asset or configuration should be changed instead.
6. **Verify, then report.** Run relevant checks after editing. Report commands actually run, results, failures, and checks that could not be run. Never claim a test passed unless it was executed and passed.
7. **Review the diff.** Inspect `git diff` and `git status` before finishing. Summarize meaningful changes and call out risks, assumptions, and follow-up work.

## Godot 4 development

- Target Godot 4.x. Confirm the installed engine version with `godot --version` (or the platform-specific executable) rather than assuming a version.
- Prefer built-in Godot features and typed GDScript where they improve clarity and maintainability. Follow the language and project conventions already in use; do not migrate languages or restructure the project without approval.
- Keep scene, script, resource, and project-setting changes consistent with one another. When renaming or moving assets, inspect and update all references; avoid breaking `res://` paths, signal connections, resource UIDs, or scene ownership.
- Avoid fragile node lookups and implicit scene-tree assumptions where a clear exported reference, signal, or well-defined interface is more maintainable.
- Keep gameplay logic testable where practical by separating important rules from presentation, input plumbing, and scene setup. Do not over-engineer simple features solely to make them testable.
- Preserve editor-authored scene and resource formatting where practical. Do not hand-edit opaque or generated import metadata unless necessary.
- Check for engine warnings and errors. Do not suppress warnings simply to make output look clean; resolve the cause or explain why a warning is acceptable.
- Do not assume a graphical editor is available in the agent environment. Use headless checks when possible and clearly identify anything that still needs a manual editor or interactive run.

## Testing and verification

Use the project's existing test framework and documented commands when available. Do not add a testing framework merely by default; propose it first if its cost or maintenance impact is meaningful.

For a Godot project, use the following verification ladder, adapting commands to the installed executable and project state:

1. **Static/project validation:** run a headless editor scan/import where practical:
   `godot --headless --path . --editor --quit`
2. **Headless startup/smoke test:** if the project is runnable and does not require interactive input:
   `godot --headless --path . --quit-after 10`
   Adjust the timeout or command to fit the task; do not treat a timeout or intentional long-running process as a pass.
3. **Automated tests:** run the existing test suite. If no suite exists, add focused automated tests for nontrivial logic when practical, or propose a lightweight testing approach before introducing dependencies.
4. **Manual/editor checks:** for changes involving visuals, input, audio, animation, scene composition, or other interactive behavior that headless checks cannot validate, provide a concise checklist for a human to verify in the Godot editor or running game.

- Run the narrowest relevant check first, then broader checks when the change warrants it.
- After fixing a failure, rerun the failed check. If practical, run a smoke test after the full suite.
- Distinguish errors introduced by the change from pre-existing failures. If uncertain, report the uncertainty instead of guessing.
- Do not create fake test results, empty tests that only pass, or tests that merely duplicate implementation details.
- If Godot is not on `PATH`, look for an existing project-specific executable/configuration or ask the user. Do not download or install software without permission.
- If a command cannot run in the current environment, say why and provide the exact command the user can run locally.

## Git workflow and change safety

- Git is the source of truth for change tracking. Inspect `git status --short` before editing and preserve unrelated changes.
- Make changes on the current branch unless the user asks otherwise. Do not create branches, commits, tags, pushes, releases, or pull requests unless explicitly requested.
- Never use destructive Git commands or discard user changes. Do not run `git reset --hard`, `git clean`, forced checkout, or similar destructive operations.
- Do not stage or commit files automatically. When useful, suggest a concise commit message, but leave staging and committing to the user unless asked.
- Do not amend, rewrite, or remove existing commits unless explicitly authorized.
- Before finishing, inspect `git diff --check`, `git diff --stat`, `git diff`, and `git status --short` as applicable. Review untracked files separately because ordinary `git diff` does not show their contents.
- Keep generated outputs, editor caches, imported artifacts, logs, and machine-specific settings out of version control where appropriate. Check the existing `.gitignore` before changing it; do not broadly ignore source assets or project files.
- If a change could remove or overwrite data, stop and ask before proceeding.

## Code quality

- Prefer clear names, small cohesive functions, explicit ownership, and simple control flow.
- Avoid duplicated logic when a small shared abstraction is justified, but do not create generic frameworks for one-off needs.
- Handle expected failure cases explicitly. Avoid broad exception/error suppression and silent fallbacks that hide defects.
- Keep comments focused on intent, invariants, and non-obvious tradeoffs rather than narrating the code.
- Update relevant documentation when behavior, setup, commands, or architecture changes.
- Do not claim compatibility with a Godot version or platform unless it has been checked or is supported by clear evidence.

## Communication

- Ask a concise question when a missing decision would materially affect architecture, behavior, data safety, or test validity. Otherwise proceed with a stated, reversible assumption.
- Before a large or risky change, explain the plan and likely impact.
- At completion, report:
  - what changed;
  - tests/checks run and their outcomes;
  - checks not run and why;
  - known limitations or decisions needing user input.
- Keep reports factual and concise. Clearly label assumptions and unverified behavior.
