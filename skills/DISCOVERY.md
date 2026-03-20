# Skill Discovery — Finding Skills Before Project Generation

Before starting intake questions, the Orchestrator searches for relevant skills that might help with the project.

---

## When to Run Skill Discovery

Run skill discovery:
1. **Before intake** — when the human first describes their project idea
2. **During intake** — when a feature is mentioned that might have a specialized skill
3. **Before implementation** — when an Implementer encounters an unfamiliar pattern

---

## Discovery Process

### Step 1: Extract Keywords

From the project description or feature request, extract:
- Technology names (e.g., "Stripe", "Twilio", "SendGrid")
- Problem domains (e.g., "payments", "notifications", "search")
- Pattern types (e.g., "authentication", "file upload", "real-time")

### Step 2: Search ClawHub

```bash
# Search ClawHub for skills matching keywords
clawhub search "[keyword]" --limit 5

# Example searches:
clawhub search "stripe payments"
clawhub search "email sendgrid"
clawhub search "push notifications"
clawhub search "elasticsearch"
```

### Step 3: Check Local Skills

Check if any relevant skills are already installed:
```bash
# List installed skills
ls ~/.agents/skills/
ls ~/.openclaw/workspace/skills/

# Check skill index
cat skills/SKILLS.md | grep -i "[keyword]"
```

### Step 4: Suggest to Human

If a relevant skill is found on ClawHub but not installed:

```
I found a skill that might help with this project:

**[Skill Name]** — [description]
Source: clawhub.com/skills/[skill-id]

This skill provides patterns for [what it does].

Should I install it? (yes/no)
```

If human says yes:
```bash
clawhub install [skill-id]
```

---

## Integration with Intake

Add to `intake/INTERACTIVE.md` after the opening message but before Group 1:

```markdown
## Pre-Intake: Skill Discovery

Before asking intake questions:

1. Ask the human: "In one sentence, what are you building?"
2. Extract keywords from their response
3. Search ClawHub for relevant skills
4. If skills found: present them, ask if they should be installed
5. Update skills/SKILLS.md if new skills installed
6. Proceed to Group 1

This ensures the factory has all relevant skills before planning begins.
```

---

## Skill Categories to Search

When the project mentions these features, search for corresponding skills:

| Feature mentioned | Search terms |
|---|---|
| Payments | stripe, payments, billing, subscriptions |
| Email | sendgrid, email, mailgun, ses |
| SMS/Phone | twilio, sms, phone, verification |
| Search | elasticsearch, algolia, search, full-text |
| Maps/Location | maps, geocoding, location, google-maps |
| Analytics | analytics, tracking, mixpanel, amplitude |
| AI/ML | openai, anthropic, langchain, embeddings |
| Video | video, streaming, mux, cloudflare-stream |
| PDF | pdf, document, generation |
| Calendar | calendar, scheduling, booking |

---

## Adding New Skills to the Factory

When a skill is installed and proves useful:

1. Add it to `skills/SKILLS.md` in the appropriate section
2. If it's stack-specific, create a reference in `skills/stack/[skill].md`
3. If it's a general pattern, create a reference in `skills/general/[skill].md`
4. Update `brain/patterns/INDEX.md` if it provides reusable patterns
