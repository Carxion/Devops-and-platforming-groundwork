# Interview scorecard: <role and level>

**Candidate:** <name> · **Interviewer:** <name> · **Stage:** <e.g. technical deep dive> · **Date:** YYYY-MM-DD

Fill this in **before** the debrief, and don't discuss the candidate with other interviewers until everyone has. See [Hiring and onboarding](../02-hiring-and-onboarding.md#structured-interviews).

## Scores

Score only the areas your stage covers.

| Score | Means |
|---|---|
| 1 | Strong no: clear evidence against, for this level |
| 2 | Leaning no: some evidence, important gaps |
| 3 | Leaning yes: meets the bar, with minor gaps |
| 4 | Strong yes: clearly exceeds the bar for this level |

| Area | Score (1 to 4) | Evidence (what they said or did, not impressions) |
|---|---|---|
| Troubleshooting and systems thinking | | |
| Infrastructure as code and automation | | |
| Cloud and networking | | |
| Reliability and operations | | |
| Security habits | | |
| Communication and collaboration | | |

**Overall recommendation:** Strong no / Leaning no / Leaning yes / Strong yes

**What would you want the next interviewer to probe?**

---

## Question bank

Ask the same core questions of every candidate for the role; use follow-ups to go deeper. Listen for reasoning and specifics, not the "right answer".

### Troubleshooting and systems thinking

- A service's response times doubled after a deploy, but error rates are normal. Walk me through how you'd find out why. *(Listen for: hypotheses, checking what changed, metrics before guesses, looking at dependencies.)*
- A container keeps restarting in production. What do you look at, in what order? *(Exit codes, logs, OOM kills, probes, recent changes; see [Docker troubleshooting](../../software/containers/docker/09-troubleshooting.md).)*
- Tell me about the hardest production problem you've debugged. What made it hard, and what did you learn?

### Infrastructure as code and automation

- How would you structure Terraform for three environments and several teams? What goes in modules, and how do changes reach production?
- Someone changed a resource by hand in the console. How do you find out, and what do you do about it?
- When would you not automate something?

### Cloud and networking

- An application in a private subnet can't reach a database in another network. Walk me through what you'd check. *(Routing, security groups or NSGs, DNS, peering, the database's own firewall.)*
- How should a CI pipeline get credentials to deploy to a cloud account?  *(Short-lived credentials through OIDC federation, not stored keys.)*

### Reliability and operations

- How would you decide what to alert on for a new service? *(Symptoms users feel, SLOs, actionable alerts with runbooks.)*
- Tell me about an incident you were part of. What happened after it was resolved?
- What makes on-call sustainable, in your experience?

### Security habits

- You find an access key committed to a repository last month. What do you do, in order? *(Revoke and rotate first, then investigate use, then clean history and prevent recurrence.)*
- What does least privilege look like for a service running in Kubernetes?

### Collaboration

- Tell me about a technical decision you disagreed with. What did you do?
- How do you explain a technical risk to someone non-technical who has to decide whether to accept it?
- Describe a time you made a mistake in production. How did you handle it?

## Practical exercise ideas

Close to the real job, about 60 to 90 minutes, in a sandbox:

- Fix a broken service: a container that won't start, a pipeline that fails, or a Kubernetes deployment that isn't ready
- Review a pull request (Terraform, Kubernetes manifests, or a Dockerfile) seeded with a security flaw and a reliability problem
- Read a dashboard and logs from a simulated incident and explain what happened
