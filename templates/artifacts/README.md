templates/artifacts/
Templates the sk.* commands use when they create a file. Unit paths follow
.claude/skills/governance/phase-layout.md. A template is used only when a file is created; an existing
file keeps its own format. Artifacts with no template here (plan.md, tasks.md, progress.md, delivery.md,
test-report.md, review.md, uat-report.md, security-report.md) take the structure their command defines.

Unit artifacts
intent-template.md                 specs/intents/{intent}/intent.md                        (sk.story)
unit-brief-template.md             units/{unit}/unit-brief.md — Impacted Projects          (sk.story)
story-template.md                  units/{unit}/01-story/story.md                          (sk.story)
architecture-template.md           02-design/architecture.md                               (sk.design)
impact-analysis-template.md        02-design/impact-analysis.md                            (sk.design)
contract-changes-template.md       02-design/contract-changes.md — change list + test plan (sk.design)
project-design-template.md         02-design/projects/{Project}.md                         (sk.design)
ui-model-template.md               02-design/ui-model.md                                   (sk.design)
investigation-report-template.md   units/{unit}/investigation-report.md                    (sk.investigate)
unit-knowledge-base-template.md    units/{unit}/knowledge-base.md                          (sk.investigate, sk.design, sk.review)

Knowledge homes (created only when absent)
adr-template.md                    specs/adr/NNNN-kebab-title.md, unless knowledge.adr.exemplar (sk.adr)
adr-index-template.md              specs/adr/adr-index.md — router                         (sk.adr, sk.init)
work-pipeline-adr-template.md      the adopting project's work-pipeline ADR                (sk.init, on acceptance)
bounded-contexts-template.md       specs/domain/bounded-contexts.md                        (sk.design, sk.init)
domain-template.md                 specs/domain/{module}.md (knowledge.domain.template: default) (sk.design)
rule-template.md                   .claude/rules/{area}/<topic>.md                         (sk.ship promotion, sk.adr)
skills-registry-template.md        .claude/skills/README.md ## Registry                    (sk.init)
projects-index-template.md         .specify/memory/projects/index.md                       (sk.init)
tech-stack-template.md             .specify/memory/projects/{Project}/tech-stack.md        (sk.init)

templates/project/ holds the files sk.init seeds: .specify/profile.yaml and .claude/rules/principles.md.
