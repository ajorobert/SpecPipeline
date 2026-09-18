Tech Stack
Loaded by: sk.plan, sk.design_sub_contracts, sk.test, sk.uat
Changes require an ADR.
Workspace mode: each project has its own .specify/memory/projects/{Project}/tech-stack.md, which wins over this file.

Backend:

Databases:

Frontend Surfaces:
# One line per surface: framework + version, language, platform (browser | native), E2E tooling.

Infrastructure:

Observability Tooling:

Test Layout:
# Where runnable tests live under each code root, per kind. sk.design_sub_contracts / sk.test_sub_testproject write tests here.
# unit:        {path pattern}
# integration: {path pattern}
# contract:    {provider path pattern} | {consumer path pattern}
# component:   {path pattern}
# e2e:         {path pattern}

Forbidden Skip Idioms:
# Syntax in the chosen test framework(s) that skips or focuses a test. sk.test fails a suite that uses them
# without a documented reason.

Constraints:
