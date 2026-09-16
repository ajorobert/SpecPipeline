PHR-{NNN}: {Feature or Command Name}
Date: {date}
Related Command: {sk.* command that triggered this}
Intent: {active_intent_id from .claude/session.yaml}
Unit: {active_unit_id from .claude/session.yaml}

Prompt or Decision Recorded
{The prompt or decision being logged}

Context at Time of Decision
{What the system state was, what constraints existed}

Outcome
{What was decided or generated}

Rationale
{Why this outcome over alternatives}

Alternatives Rejected
| Alternative | Reason Rejected |
|-------------|----------------|

Lessons
{Anything worth noting for future similar decisions}
