templates/artifacts/
Document templates used by sk.* skills when creating artifacts. Unit paths follow
.claude/skills/governance/phase-layout.md; knowledge homes follow .claude/skills/governance/profile.md.
A template is used only when a file is created; an existing file keeps its own format.

Unit artifacts
intent-template.md               specs/intents/{intent}/intent.md                         (sk.story_sub_specify)
unit-brief-template.md           units/{unit}/unit-brief.md — Impacted Projects table     (sk.story_sub_specify, sk.story_sub_architect-probe)
story-template.md                units/{unit}/01-story/story.md                           (sk.story_sub_specify)
architecture-template.md         02-design/architecture.md                                (sk.design_sub_architecture)
impact-analysis-template.md      02-design/impact-analysis.md                             (sk.design_sub_architecture)
contract-changes-template.md     02-design/contract-changes.md — change list + test plan  (sk.design_sub_contracts)
project-design-template.md       02-design/projects/{Project}.md                          (sk.design_sub_contracts, sk.design_sub_ui-design)
ui-model-template.md             02-design/ui-model.md                                    (sk.design_sub_ui-design)
security-audit-template.md       reference checklist for 07-security-audit/               (sk.security-audit)
investigation-report-template.md units/{unit}/investigation-report.md                     (sk.investigate)
unit-knowledge-base-template.md  units/{unit}/knowledge-base.md (tier 3)                  (sk.knowledge-base)
guide-template.yaml              units/{unit}/guide.yaml                                  (sk.design)

Knowledge homes (created only when absent)
system-knowledge-base-template.md  specs/knowledge-base.md (tier 1)                       (sk.init, sk.knowledge-base)
adr-template.md                  specs/adr/NNNN-kebab-title.md (unless knowledge.adr.exemplar) (sk.adr)
adr-index-template.md            specs/adr/adr-index.md — router                          (sk.adr, sk.init)
bounded-contexts-template.md     specs/domain/bounded-contexts.md                         (sk.design_sub_architecture, sk.init)
domain-template.md               specs/domain/{module}.md (knowledge.domain.template: default) (sk.design_sub_datamodel, sk.knowledge-base)
rule-template.md                 .claude/rules/{stack}/<topic>.md                         (promotion in sk.ship)
skills-registry-template.md      .claude/skills/README.md ## Registry                     (sk.init)
projects-index-template.md       .specify/memory/projects/index.md                        (sk.init)
tech-stack-template.md           .specify/memory/projects/{Project}/tech-stack.md         (sk.init, sk.plan refresh)

History
phr-template.md                  history/prompts/{feature}/PHR-{NNN}-{date}.md            (sk.phr)
