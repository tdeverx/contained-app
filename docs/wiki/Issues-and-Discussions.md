# Issues and Discussions

Use the smallest place that fits the work. Discussions are for shaping ideas
and helping people; issues are for tracked work.

## When To Use Discussions

Use Discussions when the topic is open-ended:

- **Q&A**: setup help, "how do I..." questions, and unclear behavior.
- **Ideas**: early feature thoughts before there is a concrete task.
- **Development and architecture**: use the starter thread in General for
  package boundaries, design-system direction, navigation strategy, backend
  choices, release process, and automation design until GitHub category setup is
  customized further.
- **Show and tell**: screenshots, workflows, examples, and experiments.
- **General**: anything that does not fit elsewhere.

When a discussion becomes concrete, a maintainer can turn it into one or more
issues with acceptance criteria.

## When To Use Issues

Use issues for work that can be triaged, labeled, and completed:

- Bugs, crashes, and regressions.
- Accepted feature proposals.
- Exploration tasks with a clear question to answer.
- Design-system, navigation, backend, release, or documentation tasks.
- Parent issues that collect related sub-issues and checklists.

Blank issues are disabled so each report starts with enough structure.

## Good Bug Reports

Helpful bug reports usually include:

- What happened and what you expected instead.
- Steps to reproduce, if you have them.
- Contained version, macOS version, and `container --version` when relevant.
- Screenshots, logs, crash snippets, or Reveal CLI output.

Remove tokens, private paths, and personal data before posting logs.

## Good Feature Proposals

Helpful feature proposals explain:

- The problem or opportunity.
- The behavior you want Contained to have.
- The expected user workflow.
- Acceptance criteria that make the work feel done.
- Related discussions, issues, or docs.

Early ideas can start in Discussions first.

## Exploration And Architecture Issues

Exploration and architecture issues should name the decision they need to
support. Good checklists include docs to review, alternatives to compare, risks
to call out, and the expected output: recommendation, implementation issue, or
no-go.

Feature, architecture, backend, navigation, design-system, and exploration
issues should usually include both a research/design checklist and an
implementation checklist. Bug and crash reports can stay shorter until a
maintainer has enough context to triage them.

Architecture issues can be parents for smaller implementation issues when the
work crosses package, navigation, design-system, or backend boundaries.

Use GitHub's native relationship fields when the relationship affects planning:

- Use parent/sub-issues for work breakdown under a larger theme.
- Use blocked-by/blocking links only when one issue genuinely cannot move until
  another issue is resolved.
- Keep softer context, alternatives, and inspiration as plain related links.

Use milestones as target buckets rather than labels:

- `beta`: work expected before the next beta.
- `stable`: work needed for the first stable-release bar.
- `future`: accepted work that is unscheduled or likely post-beta.

## Pull Requests

Pull requests should link a tracked issue when they change user-facing behavior,
architecture, runtime/backend behavior, release/workflow policy,
security/auth/networking, or anything that needed design/research.

Small docs fixes, dependency bumps, typo fixes, and direct review follow-ups do
not need a separate issue when the PR explains why. This is guidance, not a
hard CI gate.

## Labels

Labels are short and color-coded instead of prefixed:

- **Type:** `bug`, `feature`, or `other`.
- **Area:** neutral labels: `app`, `core`, `design`, `navigation`, `backend`,
  `docker`, `release`, and `repo`.
- **Status:** `triage`, `planned`, `backlog`, `up-next`, `in-progress`,
  `needs-info`, `needs-design`, `released`, `blocked`, or `wont-fix`.
- **Priority:** `urgent`, `high`, or `low`. No priority label means normal.
- **Special:** neutral labels such as `duplicate`, `help-wanted`,
  `good-first-issue`, `no-release-note`, and `wiki-approved`.

Codex may suggest labels, title changes, code pointers, exploration notes, and
checklists. It may rewrite maintainer-authored issue bodies when asked, but it
should not rewrite third-party issue bodies, convert a discussion into an issue,
or make broad issue changes without maintainer approval.
