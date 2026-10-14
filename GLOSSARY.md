# Glossary

Short definitions of terms used across software engineering, DevOps, cloud, and security. They're written for someone new to a team who hears a term in a meeting and needs the gist. Each definition gives the common industry meaning; a team or vendor may use a term more narrowly, so check how the people around you use it.

Terms are grouped by topic and sorted alphabetically within each group. Abbreviations are listed under the short form, with the full name in parentheses. The last section maps AWS and Azure service names to each other.

## Contents

- [Software engineering](#software-engineering)
- [Architecture and design](#architecture-and-design)
- [APIs and integration](#apis-and-integration)
- [Source control and collaboration](#source-control-and-collaboration)
- [Continuous integration and delivery](#continuous-integration-and-delivery)
- [Infrastructure as code](#infrastructure-as-code)
- [Linux and the shell](#linux-and-the-shell)
- [Containers and Kubernetes](#containers-and-kubernetes)
- [Cloud](#cloud)
- [Networking](#networking)
- [Identity and access](#identity-and-access)
- [Security](#security)
- [Observability and reliability](#observability-and-reliability)
- [Data and storage](#data-and-storage)
- [Cost](#cost)
- [Delivery, teams, and governance](#delivery-teams-and-governance)
- [AWS and Azure equivalents](#aws-and-azure-equivalents)

---

## Software engineering

- **API (application programming interface):** The contract one piece of software offers others: the operations it accepts, their inputs and outputs, and their errors. In web services it usually means HTTP endpoints.
- **Backward compatibility:** A new version still works with clients, data, or configuration made for the old one. Breaking it forces every consumer to change at once.
- **Circuit breaker:** A pattern that stops calling a failing dependency for a while after repeated errors, so the failure doesn't spread and the dependency gets time to recover.
- **Coupling and cohesion:** Coupling is how much one component depends on another's internals; cohesion is how closely the parts of one component belong together. Aim for loose coupling and high cohesion.
- **Dependency:** Code your code relies on, such as a library, a service, or a package. *Transitive* dependencies are the dependencies of your dependencies.
- **Dependency injection:** Passing a component the things it needs (a database client, a clock) instead of having it construct them, which makes it easier to test and reconfigure.
- **Event-driven architecture:** Components communicate by publishing events ("order placed") that others subscribe to, instead of calling each other directly.
- **Idempotent:** Doing an operation twice has the same effect as doing it once. Retries and automation are only safe on idempotent operations.
- **Integration test:** A test that checks several components working together, such as code and a real database.
- **Linter:** A tool that flags likely mistakes and style problems in code without running it.
- **Microservices:** An architecture of small services, each owning one business capability and its data, deployed independently. The opposite is a *monolith*, one deployable unit.
- **Mock, stub, fake:** Stand-ins for real dependencies in tests. A stub returns fixed answers, a mock also checks how it was called, and a fake is a simplified working version (an in-memory database).
- **Race condition:** A bug whose outcome depends on the timing of concurrent operations, so it appears intermittently.
- **Refactoring:** Changing code's structure without changing its behavior, usually to make the next change easier.
- **Regression:** Something that used to work and broke because of a later change.
- **REST:** See [APIs and integration](#apis-and-integration).
- **Semantic versioning (SemVer):** Version numbers in the form MAJOR.MINOR.PATCH. A major bump signals breaking changes, minor adds features, and patch fixes bugs.
- **Static analysis:** Examining code without running it, to find bugs, style problems, or security flaws. Linters and SAST tools are both static analysis.
- **Technical debt:** The future cost of shortcuts taken now. Like financial debt, it is sometimes worth taking on deliberately, and it accrues interest if ignored.
- **Test pyramid:** The guideline to have many fast unit tests, fewer integration tests, and few slow end-to-end tests.
- **Twelve-factor app:** A widely used set of principles for building services that run well in the cloud, such as keeping configuration in the environment and treating processes as stateless.
- **Unit test:** A fast test of one small piece of code in isolation.

## Architecture and design

- **Aggregate:** In domain-driven design, a cluster of entities and value objects treated as one unit for changes, with one *aggregate root* that outside code goes through. Each transaction changes one aggregate.
- **Anti-corruption layer:** A translation layer between your model and another system's, so the other system's concepts and quirks don't leak into yours. Common when integrating with legacy systems.
- **Backend for frontend (BFF):** A separate backend service for each kind of client (web, mobile), shaped to what that client needs.
- **Backpressure:** A way for an overloaded consumer to slow its producers down, instead of being overwhelmed or dropping work.
- **Blast radius:** How much is affected when something fails or goes wrong: one request, one cell, one zone, or everything. Architects design to keep it small, with isolation such as separate accounts, cells, and progressive rollouts.
- **Bounded context:** In domain-driven design, a boundary within which one model and its terms have one consistent meaning. "Customer" can mean different things in billing and in support; each is its own bounded context. Bounded contexts are a common guide for drawing service boundaries.
- **Bulkhead:** Isolating resources (thread pools, connections, instances) per dependency or customer, so one overloaded part can't sink the rest.
- **Cell-based architecture:** Splitting users or tenants across several independent copies of a system (cells), so a failure or bad deployment affects only one cell.
- **Clean architecture and onion architecture:** Layered designs where business logic sits at the center and depends on nothing outside it; frameworks, databases, and user interfaces sit at the edges and depend inward.
- **Context map:** A diagram of the bounded contexts in a system and how they relate, such as which one is upstream, and where translation happens.
- **CQRS (command query responsibility segregation):** Using separate models for changing data (commands) and reading it (queries), so each can be shaped and scaled for its job. Often paired with event sourcing, but doesn't require it.
- **DDD (domain-driven design):** An approach to software design that centers the code on a model of the business domain, built with domain experts and expressed in their language. Its *strategic* side covers bounded contexts and how they relate; its *tactical* side covers building blocks such as entities, value objects, aggregates, and domain events.
- **Domain event:** A record of something meaningful that happened in the domain, named in the past tense ("PaymentReceived").
- **Domain:** The business area the software serves, such as lending, logistics, or claims. A *subdomain* is one part of it; the *core* subdomain is where the business competes, and *supporting* and *generic* subdomains are candidates for simpler or off-the-shelf solutions.
- **DRY, KISS, YAGNI:** Don't repeat yourself; keep it simple; you aren't gonna need it. Rules of thumb against duplication, needless complexity, and building for imagined future needs.
- **Entity and value object:** In domain-driven design, an entity has an identity that lasts through changes (a customer); a value object is defined only by its values and is immutable (an address, an amount of money).
- **Event sourcing:** Storing every change to state as an append-only sequence of events, and deriving current state by replaying them. It gives a complete history, at the cost of more complex reads and schema changes.
- **Fitness function:** An automated check that a system still has a property its architecture requires, such as "no public storage" or "p95 latency under 300 ms", usually run in CI. From *Building Evolutionary Architectures*.
- **Golden path (paved road):** A supported, pre-built way to do a common task (create a service, add a database), with the platform's security, observability, and deployment decisions built in, so the right way is also the easy way.
- **Hexagonal architecture (ports and adapters):** Business logic talks to the outside world only through interfaces (ports), with swappable implementations (adapters) for databases, queues, and APIs. This makes the logic testable without infrastructure.
- **Layered architecture:** Organizing code into layers, such as presentation, business logic, and data access, where each layer calls only the one below it.
- **Lock-in:** The cost of switching away from a provider, product, or technology. A trade-off for the features and speed that provider-specific services offer, not a defect in itself.
- **Modular monolith:** One deployable application split internally into well-separated modules with clear boundaries. It offers much of the design benefit of microservices without the operational cost, and can be split later.
- **Outbox pattern:** Writing outgoing messages to a table in the same database transaction as the data change, then publishing them from there. It prevents the data from changing without the message going out, or the reverse.
- **Pilot light, warm standby:** Disaster recovery strategies. Pilot light keeps data replicated and core infrastructure ready but mostly off in a recovery region; warm standby runs a scaled-down full copy. Both sit between backup-and-restore and active-active in cost and recovery speed.
- **Publish-subscribe (pub/sub):** Senders publish messages to a topic without knowing who receives them; every subscriber to the topic gets a copy.
- **Quality attribute:** A non-functional requirement that says how well a system must do its job: availability, latency, scalability, recoverability, security, operability, cost. Most architectural decisions are driven by these.
- **Repository pattern:** An interface that looks like a collection of domain objects and hides how they're stored.
- **Retry with exponential backoff and jitter:** Retrying a failed call after waits that grow each time, with randomness added so many clients don't retry in lockstep.
- **Saga:** A way to run a business process across several services without a distributed transaction: a series of local steps, each with a *compensating action* that undoes it if a later step fails. Coordinated either by a central orchestrator or by services reacting to each other's events (choreography).
- **Separation of concerns:** Dividing a program so each part handles one aspect of the problem.
- **Service discovery:** How services find each other's current network addresses, through DNS, a registry, or the platform (Kubernetes Services).
- **SOA (service-oriented architecture):** An earlier style of building systems from networked services, often through a shared enterprise service bus. Microservices grew out of it with smaller services and fewer shared components.
- **SOLID:** Five object-oriented design principles: single responsibility, open-closed, Liskov substitution, interface segregation, and dependency inversion.
- **Strangler fig pattern:** Replacing a legacy system gradually, by routing one piece of functionality at a time to a new implementation until the old system can be switched off.
- **STRIDE:** A threat-modeling checklist: spoofing, tampering, repudiation, information disclosure, denial of service, and elevation of privilege.
- **Ubiquitous language:** In domain-driven design, the shared vocabulary that developers and domain experts both use, in conversation and in the code, within a bounded context.

## APIs and integration

- **API contract:** The agreed definition of an API's operations, data shapes, and errors, ideally written down in a machine-readable form such as OpenAPI.
- **API-first design:** Designing and reviewing the API contract before writing the implementation, so consumers can give feedback and build against it early.
- **API gateway:** A managed entry point in front of APIs that handles routing, authentication, rate limits, and logging, such as Amazon API Gateway or Azure API Management.
- **API key:** A static secret that identifies the calling application. Simple, but it identifies an app rather than a user and is easy to leak; prefer OAuth tokens where possible.
- **API versioning:** Keeping old clients working while an API changes, by putting a version in the URL (`/v2/`), a header, or a media type. Additive changes (new optional fields) usually don't need a new version.
- **AsyncAPI:** A specification format like OpenAPI, for event-driven and message-based APIs.
- **Breaking change:** A change that makes existing clients fail, such as removing a field, renaming an endpoint, or making an optional field required.
- **Contract testing:** Testing that a provider and its consumers agree on the API contract, without running both together. Pact is a common tool.
- **CORS (cross-origin resource sharing):** Browser rules, set through response headers, for which other websites' scripts may call an API.
- **Deprecation:** Announcing that part of an API will be removed, with a date and a replacement. The `Deprecation` and `Sunset` HTTP headers can signal it.
- **ETag and conditional requests:** An ETag is a version identifier for a resource. Clients send it back (`If-None-Match`, `If-Match`) to skip downloading unchanged data, or to avoid overwriting someone else's update.
- **GraphQL:** A query language for APIs where the client asks for exactly the fields it needs, usually through one endpoint. Good for varied clients; harder to cache and to protect from expensive queries.
- **gRPC:** A high-performance RPC framework from Google that uses HTTP/2 and Protocol Buffers, with support for streaming. Common for service-to-service calls.
- **HATEOAS:** Hypermedia as the engine of application state: a REST constraint where responses include links to the actions available next. Few APIs implement it fully.
- **HTTP methods:** GET reads; POST creates or triggers an action; PUT replaces; PATCH partially updates; DELETE removes. GET, PUT, and DELETE should be idempotent; POST is not.
- **HTTP status codes:** 2xx success (200 OK, 201 Created, 204 No Content); 3xx redirects; 4xx client errors (400 Bad Request, 401 Unauthenticated, 403 Forbidden, 404 Not Found, 409 Conflict, 429 Too Many Requests); 5xx server errors (500, 502 Bad Gateway, 503 Unavailable, 504 Gateway Timeout).
- **HTTP/2 and HTTP/3:** Newer versions of HTTP. HTTP/2 sends many requests over one connection; HTTP/3 runs over QUIC (on UDP) to cut connection setup time and cope better with packet loss.
- **Idempotency key:** A unique ID a client sends with a request, so that if the request is retried the server performs the action only once. Standard for payment and order APIs.
- **JSON Schema:** A vocabulary for describing and validating the structure of JSON documents. OpenAPI uses it for request and response bodies.
- **JWT (JSON Web Token):** A signed, compact token carrying claims (who the caller is, when the token expires), which servers can verify without a database lookup. Used by OAuth and OIDC.
- **Long polling:** The client sends a request that the server holds open until there's new data or a timeout, then the client asks again. A fallback when push isn't available.
- **OpenAPI:** The standard, machine-readable format (formerly Swagger) for describing REST APIs. Tools generate documentation, client libraries, mock servers, and tests from it.
- **Pagination:** Returning large result sets in pages. *Offset* pagination (`?page=3`) is simple but slow and inconsistent on large or changing data; *cursor* pagination (`?after=<token>`) is more reliable.
- **Problem Details:** A standard JSON format for HTTP API errors (RFC 9457), with a type, title, status, and detail.
- **Protocol Buffers (protobuf):** Google's compact binary format for structured data, defined in `.proto` schema files. Used by gRPC.
- **Rate limiting and throttling:** Capping how many requests a client can make in a time window, usually answered with `429 Too Many Requests` and a `Retry-After` header.
- **REST (representational state transfer):** The most common style of web API: resources identified by URLs, manipulated with standard HTTP methods, and represented usually as JSON. Requests are stateless, so each carries everything the server needs.
- **RPC (remote procedure call):** Calling a function on another machine as if it were local. gRPC, JSON-RPC, and tRPC are RPC styles; REST is built around resources instead of procedures.
- **SDK (software development kit):** A client library that wraps an API for a particular language, such as the AWS SDK for Python (boto3).
- **Server-sent events (SSE):** A one-way stream of events from server to browser over a plain HTTP connection. Simpler than WebSockets when only the server needs to push.
- **SOAP:** An older, XML-based protocol for web services with strict contracts described in WSDL. Still common in enterprise, finance, and legacy integrations.
- **Webhook:** An HTTP callback: a service calls your URL when an event happens, instead of you polling it. Verify webhook signatures and process them idempotently, because they can arrive twice or out of order.
- **WebSocket:** A protocol for a persistent, two-way connection between client and server, used for chat, live dashboards, and collaboration.

## Source control and collaboration

- **Bisect:** A binary search through history for the commit that introduced a bug (`git bisect`), marking each tested commit good or bad, by hand or with a script.
- **Branch:** An independent line of development in a repository.
- **Branch protection:** Rules on a branch (usually the default one) such as required reviews, required passing checks, and no force-pushes.
- **Cherry-pick:** Copying one commit's changes onto another branch as a new commit, typically to bring a fix to a release branch.
- **CODEOWNERS:** A file that maps paths in a repository to the people or teams who must review changes to them.
- **Commit:** A recorded snapshot of changes in Git, with an author, a message, and a unique hash.
- **Conventional Commits:** A commit-message format (`feat:`, `fix:`, `chore:`) that tools can parse to generate changelogs and version numbers.
- **Default branch:** The branch new work merges into, usually `main`.
- **Detached HEAD:** Having a commit checked out instead of a branch. Commits made there belong to no branch until you create one.
- **Force push:** Overwriting a remote branch's history. `--force-with-lease` refuses if someone else pushed in the meantime; protected branches should block force pushes entirely.
- **Fork:** A personal copy of someone else's repository, used to propose changes without write access to the original.
- **Git:** The distributed version control system used by nearly every team. GitHub, GitLab, Bitbucket, and Azure Repos host Git repositories.
- **GitFlow:** A branching model with long-lived `develop` and `release` branches. Most teams that deploy often have moved to trunk-based development.
- **HEAD:** Git's name for what you have checked out: usually a branch, which in turn points at its latest commit.
- **Merge conflict:** Two changes touch the same lines, so Git can't combine them automatically and a person must choose.
- **Monorepo:** One repository holding many projects or services. A *polyrepo* setup gives each its own repository.
- **Pull request (PR) or merge request (MR):** A proposal to merge a branch, with review comments and automated checks. GitHub calls it a pull request and GitLab a merge request.
- **Rebase:** Replaying your commits on top of another branch to keep history linear. Never rebase commits others have already pulled.
- **Reflog:** Git's local record of where each branch and HEAD pointed over time. It's how "lost" commits are found after a reset, rebase, or deleted branch.
- **Revert:** A new commit that undoes an earlier one. The safe way to undo something on a shared branch, because history is only added to.
- **Signed commit:** A commit carrying a cryptographic signature that proves who made it.
- **Squash merge:** Combining all of a pull request's commits into one commit on merge.
- **Staging area (index):** Where the next commit is assembled: `git add` puts changes there and `git commit` records them.
- **Stash:** Uncommitted changes set aside (`git stash`) so the working tree is clean, to be reapplied later.
- **Tag:** A named pointer to a specific commit, usually marking a release (`v1.4.0`).
- **Trunk-based development:** Everyone integrates small changes into the default branch at least daily, using short-lived branches and feature flags instead of long-lived branches.
- **Worktree:** An extra working directory attached to the same repository (`git worktree add`), so two branches can be checked out at once.

## Continuous integration and delivery

- **Artifact:** The output of a build that gets deployed, such as a container image, package, or binary. Build once and promote the same artifact through every environment.
- **Artifact repository or registry:** Storage for build artifacts, such as a container registry, a package feed, or Artifactory.
- **Blue-green deployment:** Running the new version (green) beside the current one (blue) and switching traffic over at once, keeping blue ready for a fast rollback.
- **Build:** Turning source code into an artifact: compiling, packaging, and running checks.
- **Canary release:** Sending a small share of traffic to a new version and watching its metrics before rolling it out to everyone.
- **CD (continuous delivery):** Every change that passes the pipeline is releasable, and releasing is a routine, low-risk decision.
- **CD (continuous deployment):** Every change that passes the pipeline goes to production automatically, with no human release step.
- **CI (continuous integration):** Merging changes into the shared branch often, with every change built and tested automatically.
- **Deployment vs. release:** Deployment puts code on servers; release exposes it to users. Feature flags let you deploy without releasing.
- **Environment:** A full running copy of a system for a purpose, such as dev, test, staging, or production.
- **Environment promotion:** Moving the same artifact through environments in order (dev, then staging, then production), with gates between them.
- **Feature flag (feature toggle):** A runtime switch that turns a feature on or off without a deployment.
- **Flaky test:** A test that sometimes passes and sometimes fails without any code change. Flaky tests teach people to ignore failures.
- **Gate:** A check a change must pass before moving to the next stage, such as tests, a security scan, or a manual approval.
- **GitOps:** Keeping the desired state of a system in Git and having an agent (such as Argo CD or Flux) continuously make the running system match it.
- **Hermetic build:** A build whose result depends only on its declared inputs, not on the machine or the network, so it's reproducible.
- **Immutable artifact:** An artifact that is never changed after it's built. A fix produces a new version.
- **Pipeline:** The automated sequence of stages (build, test, scan, deploy) that a change goes through.
- **Rollback and roll forward:** Rolling back returns to the previous version; rolling forward fixes the problem with a new version.
- **Rolling deployment:** Replacing instances of the old version with the new one a few at a time.
- **Runner or agent:** The machine that executes pipeline jobs. It can be hosted by the CI provider or self-hosted.
- **Smoke test:** A quick check right after deployment that the system starts and its main paths respond.

## Infrastructure as code

- **Ansible:** An agentless configuration management tool: it connects over SSH (or WinRM) and runs modules that each make one thing true on the host.
- **Ansible Vault:** Ansible's built-in encryption for secrets stored in a repository. A secrets manager queried at run time is usually better for production.
- **Bicep:** Microsoft's language for declaring Azure resources. It compiles to ARM templates.
- **CloudFormation:** AWS's service for declaring AWS resources in YAML or JSON templates, deployed as *stacks*.
- **Collection (Ansible):** A distributable package of Ansible modules, plugins, and roles, such as `ansible.posix` or `amazon.aws`, installed with `ansible-galaxy`.
- **Configuration management:** Tools that set up software and settings on existing servers, such as Ansible, Chef, and Puppet.
- **Declarative:** Describing the end state you want and letting the tool work out the steps. Most IaC is declarative; scripts are *imperative*.
- **Drift:** Differences between what the code declares and what actually exists, usually from changes made by hand.
- **GitOps:** See [Continuous integration and delivery](#continuous-integration-and-delivery).
- **Golden image:** A pre-built, hardened machine or container image that teams start from.
- **Handler (Ansible):** A task that runs only when another task reports a change, once, at the end of the play. Typically restarts or reloads a service.
- **IaC (infrastructure as code):** Defining infrastructure in version-controlled files that a tool applies, instead of by hand in a console.
- **Idempotent apply:** Applying the same code twice changes nothing the second time. Good IaC is idempotent.
- **Immutable infrastructure:** Replacing servers instead of changing them in place.
- **Inventory (Ansible):** The list of hosts Ansible manages and the groups they belong to: a file, or generated from a cloud API by an inventory plugin.
- **Module:** A reusable, parameterized package of IaC, such as a standard network or database.
- **Molecule:** A testing framework for Ansible roles: it creates throwaway instances, applies the role, applies it again to check idempotence, and verifies the result.
- **OpenTofu:** An open-source fork of Terraform, maintained under the Linux Foundation.
- **Plan and apply:** Terraform's two steps. *Plan* shows what would change; *apply* makes the changes. Review the plan before applying.
- **Playbook:** An Ansible YAML file that maps groups of hosts to the roles and tasks they should get.
- **Provider:** A Terraform plugin that talks to one platform's API, such as AWS, Azure, or GitHub.
- **Pulumi:** An IaC tool that uses general-purpose languages such as TypeScript, Python, and Go.
- **Remote state:** Terraform state stored in shared storage (such as S3 or Azure Blob Storage) with locking, so a team can work on it safely.
- **Role (Ansible):** A reusable package of Ansible tasks, defaults, templates, and handlers with a standard folder layout.
- **Stack:** A set of resources deployed and managed as one unit. The word is used by CloudFormation, Pulumi, and many teams' Terraform layouts.
- **State:** Terraform's record of which real resources its code manages. It can contain secrets, so it's protected like one.
- **State lock:** A lock that stops two runs from changing the same state at once.
- **Terraform:** HashiCorp's IaC tool, which declares resources in HCL (HashiCorp Configuration Language) across many providers.
- **What-if or change set:** A preview of changes before deployment, in Azure (`what-if`) and CloudFormation (change sets).

## Linux and the shell

- **AppArmor:** Ubuntu's mandatory access control system: per-program profiles that limit which files and capabilities a program can use, even as root.
- **Bash:** The standard interactive shell and scripting language on Linux servers. On Ubuntu, `/bin/sh` is a different, smaller shell (dash).
- **cgroups (control groups):** The kernel feature that limits and accounts for the CPU, memory, and I/O of a group of processes. systemd services and containers both use them.
- **cron:** The traditional job scheduler, configured with crontab lines. systemd timers are the modern alternative.
- **Distribution (distro):** A packaged Linux operating system, such as RHEL, Rocky Linux, Ubuntu, or Debian. *Families* share a package format and tools: RPM and dnf for RHEL, deb and apt for Debian and Ubuntu.
- **EPEL (Extra Packages for Enterprise Linux):** A Fedora-maintained repository of extra packages for RHEL and its rebuilds.
- **Exit code:** The number a command returns when it finishes: 0 for success, anything else for failure. Scripts and pipelines decide what to do next from it.
- **Idempotent script:** One that leaves the same result however many times it runs, so it's safe to rerun after a failure.
- **journald:** systemd's log service. `journalctl` queries it by unit, time, priority, and boot.
- **LVM (Logical Volume Manager):** A layer between disks and filesystems that lets volumes be grown, moved, and snapshotted.
- **Namespaces:** The kernel feature that gives a process its own view of process IDs, network, mounts, and users. Containers are built from namespaces and cgroups.
- **Package manager:** The tool that installs and updates software with its dependencies: `dnf` on RHEL, `apt` on Ubuntu.
- **PID 1:** The first process in a system or container. In a container it gets no default signal handling, so it must handle SIGTERM itself to shut down cleanly.
- **Pipe:** `|`, which sends one command's output into the next command's input.
- **Regular expression (regex):** A pattern language for matching text, in three flavors on Linux: basic (BRE), extended (ERE), and Perl-compatible (PCRE).
- **RHEL (Red Hat Enterprise Linux):** Red Hat's commercially supported distribution. Rocky Linux and AlmaLinux are free rebuilds; CentOS Stream is its upstream.
- **SELinux (Security-Enhanced Linux):** RHEL's mandatory access control system: every file, process, and port has a label, and policy decides which labels may interact.
- **Shebang:** The first line of a script, such as `#!/usr/bin/env bash`, naming the interpreter that runs it.
- **Signal:** A notification sent to a process, such as SIGTERM (please stop), SIGKILL (stop now, can't be caught), or SIGHUP (often: reload configuration).
- **stdin, stdout, stderr:** A process's three standard streams: input, normal output, and error output. Redirection (`>`, `2>`, `<`) connects them to files.
- **sudo:** Runs a command as root (or another user) for permitted users, with each command logged.
- **systemd:** The init system and service manager on current Linux distributions. It starts services (*units*) at boot, restarts them, schedules timers, and collects logs.
- **Ubuntu LTS (long-term support):** Ubuntu releases published every two years and supported for five (ten with Ubuntu Pro). Servers should run LTS releases.

## Containers and Kubernetes

- **Admission controller:** A Kubernetes component that checks or changes objects before they're stored, used to enforce policy. Kyverno, Gatekeeper, and Pod Security Admission are examples.
- **AKS, EKS, GKE:** The managed Kubernetes services on Azure, AWS, and Google Cloud.
- **ConfigMap and Secret:** Kubernetes objects that hold configuration and sensitive values for pods. Secrets are only base64-encoded by default, not encrypted, unless encryption at rest is turned on.
- **Container:** A process packaged with its dependencies and isolated from others on the same host. Lighter than a virtual machine because it shares the host's kernel.
- **Container image:** The read-only template a container starts from, built from a Dockerfile or similar and stored in a registry.
- **Control plane:** The Kubernetes components that make decisions and store cluster state (API server, scheduler, etcd). Managed services run it for you.
- **CRD (custom resource definition):** A way to add new object types to Kubernetes, used by operators and add-ons.
- **DaemonSet:** Runs one copy of a pod on every node (or selected nodes), typically for agents such as log collectors.
- **Deployment:** Manages a set of identical, interchangeable pods and rolls out new versions of them.
- **Distroless image:** A container image with only the application and its runtime, without a shell or package manager, which shrinks the attack surface.
- **Docker:** The tool that popularized containers. Its image format is now standardized as OCI (Open Container Initiative).
- **Helm:** A package manager for Kubernetes. A *chart* is a templated set of manifests.
- **HPA (Horizontal Pod Autoscaler):** Adds or removes pod replicas based on metrics such as CPU use.
- **Image digest:** An image's content hash (`sha256:...`). Unlike a tag, it can't be moved to point at different contents.
- **Ingress and Gateway API:** Kubernetes objects that route outside HTTP traffic to services. Gateway API is the newer, more expressive successor to Ingress.
- **Job and CronJob:** A Job runs pods until a task completes; a CronJob creates Jobs on a schedule.
- **kubectl:** The Kubernetes command-line tool.
- **Kustomize:** A tool, built into kubectl, that customizes plain manifests with overlays instead of templates.
- **Liveness, readiness, and startup probes:** Health checks. A failed liveness probe restarts the container, a failed readiness probe removes it from traffic, and a startup probe gives slow starters time before the other two begin.
- **Manifest:** A YAML or JSON file describing a Kubernetes object.
- **Namespace:** A partition of a cluster for grouping objects and applying access rules, quotas, and policies.
- **NetworkPolicy:** Rules for which pods may talk to which. They're only enforced if the cluster's network plugin supports them.
- **Node:** A machine (usually a VM) that runs pods. A *node pool* or *node group* is a set of identical nodes.
- **OCI (Open Container Initiative):** The standards for container image formats and runtimes, so images built by one tool run in any other.
- **Operator:** A controller that manages a complex application (such as a database) on Kubernetes, using custom resources.
- **Podman:** A daemonless, rootless-by-default container engine with Docker-compatible commands; the supported container tool on RHEL.
- **Pod:** The smallest deployable unit in Kubernetes: one or more containers that share a network address and storage.
- **PodDisruptionBudget (PDB):** The minimum number of pods that must stay running during voluntary disruptions such as node upgrades.
- **Pod Security Standards:** Three built-in Kubernetes security profiles: privileged, baseline, and restricted.
- **Quadlet:** Podman's systemd integration: a `.container` file describes a container, and systemd runs it as a service.
- **Requests and limits:** The CPU and memory a container is guaranteed (requests) and may not exceed (limits). The scheduler places pods by their requests.
- **Rootless containers:** Containers run by an ordinary user, with no root daemon, so an escape lands as that user rather than root.
- **Service:** A stable network name and address in front of a changing set of pods.
- **Service mesh:** A layer (such as Istio or Linkerd) that handles service-to-service traffic, adding mutual TLS, retries, and telemetry without code changes.
- **Sidecar:** A helper container that runs beside the main container in a pod, such as a proxy or a log shipper.
- **StatefulSet:** Like a Deployment, but for pods that need stable names and their own persistent storage, such as databases.
- **Taints and tolerations:** A taint keeps pods off a node unless they carry a matching toleration. Used to reserve nodes for particular workloads.

## Cloud

- **Availability zone (AZ):** One or more isolated data centers within a region, with independent power and networking. Spreading across zones protects against a data center failure.
- **Autoscaling:** Adding or removing capacity automatically based on load or a schedule.
- **Cloud-native:** Built to use cloud capabilities such as managed services, elasticity, and automation, rather than moved unchanged from a data center.
- **Control plane and data plane:** The control plane manages resources (create, configure); the data plane carries the actual work (requests, data). Cloud outages often affect one but not the other.
- **Egress and ingress:** Traffic leaving and entering a network. Clouds usually charge for egress.
- **Elasticity:** The ability to grow and shrink capacity quickly as demand changes.
- **Hybrid cloud and multicloud:** Hybrid combines cloud with on-premises infrastructure; multicloud uses more than one cloud provider.
- **IaaS, PaaS, SaaS:** Infrastructure, platform, and software as a service. Each step up means the provider runs more of the stack and you run less.
- **Landing zone:** A pre-configured, governed cloud foundation (accounts or subscriptions, networking, identity, logging, guardrails) that new workloads are deployed into.
- **Lift and shift (rehost):** Moving an application to the cloud with little or no change. Other migration strategies include replatform, refactor, and retire.
- **Managed service:** A service the provider operates for you, such as a managed database, so you don't patch or scale servers.
- **Region:** A geographic area with a cluster of availability zones. Choice of region affects latency, cost, data residency, and which services are available.
- **Resource tagging:** Key-value labels on cloud resources (Owner, Environment, CostCenter), used for cost allocation, automation, and policy.
- **Serverless:** Running code or services without managing servers, billed per use. Functions (AWS Lambda, Azure Functions) are the best-known example.
- **Shared responsibility model:** The split of security and operations duties between the cloud provider and the customer. It shifts with the service type: the customer does more for a VM than for a managed database.
- **Spot or preemptible instances:** Spare capacity at a steep discount that the provider can reclaim at short notice. Good for interruptible work.
- **Tenant, account, subscription:** Organizational boundaries. An AWS *account* and an Azure *subscription* each hold resources and billing; an Azure *tenant* (Entra ID directory) holds identities for many subscriptions. AWS Organizations and Azure management groups group them.
- **Well-Architected Framework:** AWS's and Azure's published guidance for evaluating workloads against pillars such as reliability, security, cost, performance, and operational excellence.

## Networking

- **CDN (content delivery network):** A network of edge servers that caches content close to users, such as CloudFront or Azure Front Door.
- **CIDR (Classless Inter-Domain Routing):** Notation for an IP address range, such as `10.0.0.0/16`. A smaller suffix means a larger range.
- **DNS (Domain Name System):** Translates names (`example.com`) into IP addresses. A *record* is one entry; *TTL* is how long resolvers may cache it.
- **Firewall:** Filters traffic by rules. Cloud networks layer several: security groups or NSGs, network ACLs, and managed firewalls.
- **Hub and spoke:** A network layout where shared services (firewall, DNS, VPN) sit in a central hub network that workload spoke networks connect to.
- **Load balancer:** Spreads traffic across several targets. *Layer 4* balancers route by IP and port; *layer 7* balancers understand HTTP and can route by path or host.
- **mTLS (mutual TLS):** TLS where both sides present certificates, so each proves its identity to the other.
- **NAT (network address translation) gateway:** Lets resources in private subnets reach the internet without being reachable from it.
- **Peering:** A direct private connection between two virtual networks.
- **Private endpoint or PrivateLink:** Reaching a cloud service over a private IP address in your own network, instead of over its public endpoint.
- **Proxy and reverse proxy:** A proxy forwards requests from clients outward; a reverse proxy receives requests on behalf of servers (load balancers and API gateways are reverse proxies).
- **Public and private subnet:** A public subnet routes to the internet directly; a private one doesn't, and reaches out only through NAT, if at all.
- **Route table:** Rules that decide where traffic from a subnet goes next.
- **Security group and NSG:** Stateful allow rules attached to resources (AWS security group) or subnets and interfaces (Azure network security group).
- **TLS (Transport Layer Security):** Encryption for data in transit, the "S" in HTTPS. SSL is its obsolete predecessor, though the name lingers.
- **VPC and VNet:** A private, isolated network in the cloud: a virtual private cloud on AWS and Google Cloud, a virtual network on Azure.
- **VPN (virtual private network):** An encrypted tunnel over the internet, linking a site or a user to a private network. *Direct Connect* (AWS) and *ExpressRoute* (Azure) are dedicated private links instead.
- **WAF (web application firewall):** Filters HTTP traffic for attacks such as SQL injection and cross-site scripting. Not to be confused with the Well-Architected Framework.
- **Zero trust:** A security model that grants no trust based on network location. Every request is authenticated, authorized, and encrypted, inside the network or not.

## Identity and access

- **ABAC and RBAC:** Attribute-based and role-based access control. RBAC grants permissions through roles; ABAC decides using attributes such as tags or department.
- **Authentication (AuthN) and authorization (AuthZ):** Authentication proves who you are; authorization decides what you may do.
- **Break-glass account:** An emergency account, tightly controlled and monitored, for when normal access paths fail.
- **Entra ID:** Microsoft's cloud identity service, formerly Azure Active Directory.
- **Federation:** Trusting another system's identity tokens instead of keeping separate credentials, such as signing in to a cloud with your company's identity provider.
- **IAM (identity and access management):** The policies and systems that control who can access what. Also the name of AWS's identity service.
- **IdP (identity provider):** The system that authenticates users and issues tokens, such as Entra ID, Okta, or Google Workspace.
- **JIT (just-in-time) access:** Elevated permissions granted on request for a limited time, instead of held permanently. Azure PIM and AWS IAM Identity Center support it.
- **Least privilege:** Granting only the permissions needed for the task, and no more.
- **Long-lived credentials:** Keys or passwords that don't expire on their own, such as IAM access keys or client secrets. They're the most common source of cloud breaches; prefer short-lived tokens.
- **Managed identity and workload identity:** An identity the platform gives a workload (a VM, a function, a pod) so it can call cloud APIs without stored secrets.
- **MFA (multi-factor authentication):** Requiring two or more kinds of proof, such as a password plus a hardware key or app prompt.
- **OAuth 2.0:** A standard for delegated authorization, letting an app act on a user's behalf with a token instead of their password.
- **OIDC (OpenID Connect):** An identity layer on OAuth 2.0. CI systems use it to swap a short-lived job token for cloud credentials, so pipelines need no stored keys.
- **Permissions boundary:** An AWS limit on the most permissions a role can ever have, regardless of the policies attached to it.
- **Principal:** Any identity that can be granted access: a user, a group, a role, or a service.
- **Role:** A set of permissions that a principal can assume temporarily. In AWS, roles give short-lived credentials.
- **SAML (Security Assertion Markup Language):** An older XML-based standard for single sign-on, still common in enterprises.
- **SCIM (System for Cross-domain Identity Management):** A standard for automatically creating and removing user accounts across systems.
- **Service account or service principal:** A non-human identity for an application or automation.
- **SSO (single sign-on):** Signing in once to reach many applications.

## Security

- **Attack surface:** All the points where an attacker could try to get in: open ports, endpoints, dependencies, credentials, and people.
- **CIS Benchmarks:** Consensus hardening guides from the Center for Internet Security for operating systems, clouds, Kubernetes, and more.
- **CSPM (cloud security posture management):** Tools that scan cloud configuration for risky settings, such as AWS Security Hub and Microsoft Defender for Cloud.
- **CVE (Common Vulnerabilities and Exposures):** The public ID for a known vulnerability, such as `CVE-2021-44228`.
- **CVSS (Common Vulnerability Scoring System):** A 0–10 severity score for a vulnerability. It measures severity, not how likely exploitation is.
- **DAST (dynamic application security testing):** Testing a running application from the outside for vulnerabilities.
- **Defense in depth:** Layering independent controls so one failure doesn't mean a breach.
- **DevSecOps:** Building security into every stage of delivery, automated in the pipeline, instead of a separate review at the end.
- **Encryption at rest and in transit:** Protecting stored data, and data moving over a network.
- **EPSS (Exploit Prediction Scoring System):** An estimate of how likely a vulnerability is to be exploited in the next 30 days. Used with CVSS to prioritize.
- **Hardening:** Reducing a system's attack surface by removing unneeded software, closing ports, and tightening settings.
- **IaC scanning:** Checking infrastructure code for insecure settings before deployment, with tools such as checkov, tfsec, or KICS.
- **Incident response:** The prepared process for detecting, containing, fixing, and learning from security incidents.
- **KMS (key management service):** A managed service that creates, stores, and controls access to encryption keys. Azure's equivalent is Key Vault.
- **OWASP Top 10:** The Open Worldwide Application Security Project's list of the most critical web application security risks.
- **Penetration test (pen test):** An authorized simulated attack to find exploitable weaknesses.
- **Policy as code:** Security and compliance rules written as code that tools enforce automatically, such as OPA, Kyverno, Azure Policy, or AWS SCPs.
- **Rotation:** Replacing a credential or key on a schedule, or immediately after a suspected exposure.
- **SAST (static application security testing):** Scanning source code for security flaws without running it.
- **SBOM (software bill of materials):** A list of every component and dependency in a piece of software. Common formats are SPDX and CycloneDX.
- **SCA (software composition analysis):** Scanning dependencies for known vulnerabilities and license problems.
- **Secret:** A credential such as a password, API key, token, or private key. Keep secrets in a secrets manager, never in code.
- **Secrets manager:** A service that stores secrets and controls access to them, such as AWS Secrets Manager, Azure Key Vault, or HashiCorp Vault.
- **Secret scanning:** Detecting secrets committed to repositories or logs.
- **SIEM (security information and event management):** A system that collects security logs from many sources to detect and investigate threats, such as Microsoft Sentinel or Splunk.
- **Shift left:** Moving checks such as testing and security earlier in development, where problems are cheaper to fix.
- **SLSA (Supply-chain Levels for Software Artifacts):** A framework of levels for proving how software was built, centered on build provenance.
- **Software supply chain:** Everything that goes into your software: dependencies, build tools, pipelines, and registries. Attacks on it compromise many victims at once.
- **Threat modeling:** Systematically asking what could go wrong with a design, who might attack it, and how. STRIDE is a common method.
- **Vulnerability management:** The ongoing cycle of finding, prioritizing, fixing, and verifying vulnerabilities.

## Observability and reliability

- **Alert fatigue:** People stop responding to alerts because too many are noisy or not actionable.
- **APM (application performance monitoring):** Tools that track application performance, such as latency, errors, and traces, per request or transaction.
- **Blameless postmortem:** A written review after an incident that focuses on how the system and process allowed the failure, not on who to blame.
- **Chaos engineering:** Deliberately injecting failures to test that a system copes with them.
- **Dashboard:** A visual view of metrics. Useful for investigation, but not a substitute for alerts.
- **Error budget:** The amount of unreliability an SLO allows (for 99.9%, about 43 minutes a month). When it's spent, the team prioritizes reliability over features.
- **Four golden signals:** Latency, traffic, errors, and saturation: Google SRE's core service metrics.
- **High availability (HA):** Designing a system to keep running through component failures, usually through redundancy.
- **Incident:** An unplanned disruption or degradation of a service. Teams rank them by *severity* (SEV1 is the worst).
- **Logs, metrics, traces:** The three main kinds of telemetry. Logs are timestamped event records, metrics are numbers over time, and traces follow one request across services.
- **MTTA, MTTD, MTTR:** Mean time to acknowledge, to detect, and to recover (or restore) from an incident.
- **Observability:** How well you can understand a system's internal state from its outputs, especially for problems nobody predicted.
- **On-call:** The rotation of people responsible for responding to alerts outside working hours.
- **OpenTelemetry (OTel):** An open standard and toolkit for collecting logs, metrics, and traces without being tied to one vendor.
- **Runbook or playbook:** Step-by-step instructions for a known operational task or alert.
- **RED and USE methods:** RED (rate, errors, duration) for services; USE (utilization, saturation, errors) for resources such as CPUs and disks.
- **RPO and RTO:** Recovery point objective (how much data you can afford to lose, measured in time) and recovery time objective (how long you can afford to be down).
- **SLA (service level agreement):** A contractual commitment to customers, usually with penalties if missed.
- **SLI (service level indicator):** A measurement of service behavior that users care about, such as the share of requests that succeed within 300 ms.
- **SLO (service level objective):** The target for an SLI, such as 99.9% over 30 days. Set it tighter than any SLA.
- **SRE (site reliability engineering):** Google's approach of applying software engineering to operations, built around SLOs, error budgets, and limiting manual toil.
- **Synthetic monitoring:** Scripted checks that simulate users hitting a service from outside, to catch outages before real users do.
- **Toil:** Manual, repetitive, automatable operational work that grows with the service and has no lasting value.

## Data and storage

- **ACID:** Atomicity, consistency, isolation, durability: guarantees that database transactions are processed reliably.
- **Backup and snapshot:** A backup is a copy kept for restoring data. A snapshot is a point-in-time copy of a disk or database, which counts as a backup only if it's stored independently of the original.
- **Block, file, and object storage:** Block storage is a raw disk for one machine, file storage is a shared file system, and object storage (S3, Blob Storage) holds files as objects addressed by key over an API.
- **CAP theorem:** During a network partition, a distributed system must choose between consistency and availability.
- **Data residency:** The requirement that data stays in a particular country or region.
- **Data lake and data warehouse:** A lake stores raw data of every kind cheaply; a warehouse stores structured, modeled data for analytics.
- **Eventual consistency:** Replicas may briefly disagree after a write but converge over time.
- **ETL and ELT:** Extract, transform, load: moving data between systems. ELT loads first and transforms inside the destination.
- **Immutable backup:** A backup that can't be changed or deleted for a set period, even by administrators, which protects against ransomware.
- **Message queue and event stream:** A queue (SQS, Service Bus) hands each message to one consumer; a stream (Kafka, Kinesis, Event Hubs) keeps an ordered log that many consumers can read and replay.
- **Migration (schema):** A versioned script that changes a database's structure, applied in order.
- **NoSQL:** Databases that don't use the relational table model, such as document, key-value, wide-column, and graph databases.
- **Point-in-time restore (PITR):** Restoring a database to any moment within a retention window.
- **Read replica:** A read-only copy of a database that offloads read traffic from the primary.
- **Relational database (RDBMS):** A database of tables with relationships, queried with SQL, such as PostgreSQL, MySQL, or SQL Server.
- **Replication:** Copying data continuously to other nodes, zones, or regions, for availability or durability.
- **Sharding:** Splitting data across several databases by a key so each holds part of it.

## Cost

- **Chargeback and showback:** Billing teams for the cloud resources they use (chargeback), or just showing them the cost (showback).
- **Commitment discounts:** Lower prices in exchange for committing to usage over one or three years, such as AWS Savings Plans and Reserved Instances, or Azure reservations and savings plans.
- **Cost allocation:** Assigning cloud spend to the teams, products, or customers responsible, usually through tags and account structure.
- **FinOps:** The practice of managing cloud spending through shared accountability between engineering, finance, and the business.
- **Orphaned resources:** Resources still billing after whatever used them is gone, such as unattached disks, old snapshots, and idle IP addresses.
- **Rightsizing:** Matching resource sizes to actual use, usually by moving to smaller instances.
- **Unit cost:** Cloud spend divided by a business measure, such as cost per customer or per thousand requests. It shows whether costs scale efficiently.

## Delivery, teams, and governance

- **Acceptance criteria:** The conditions a backlog item must meet to be accepted, written before the work starts; often in Given/When/Then form.
- **ADR (architecture decision record):** A short document recording an important decision, its context, and its consequences. See the [template](tech-lead/templates/adr-template.md).
- **Agile:** Delivering in small increments with frequent feedback, rather than a single big plan. Scrum and Kanban are common forms.
- **Backlog:** The ordered list of work not yet started.
- **Bus factor:** How many people would have to leave before a project stalls for lack of knowledge. A bus factor of one is a risk.
- **Change advisory board (CAB):** A group that approves changes before release. Automated checks and small changes usually manage risk better than a meeting.
- **Change fail rate:** The share of deployments that need immediate intervention in production, such as a rollback or hotfix. One of the DORA metrics.
- **Conway's law:** Systems tend to mirror the communication structure of the organizations that build them.
- **Cost of delay:** What it costs to do something later instead of now: lost value, a missed deadline, or a risk left open. The basis of WSJF.
- **Definition of done:** The team's shared checklist for when work counts as finished, such as tested, reviewed, documented, and deployed.
- **DevOps:** A culture and set of practices that bring development and operations together, so teams build, ship, and run their own software through automation and shared responsibility.
- **DORA metrics:** Measures of software delivery performance from the DevOps Research and Assessment program. Throughput: change lead time, deployment frequency, and failed deployment recovery time. Instability: change fail rate and deployment rework rate. Earlier versions had four metrics, with mean time to restore. See [Planning and metrics](manager/03-planning-and-metrics.md#measuring-delivery-the-dora-metrics).
- **Epic, story, task:** Units of planned work, from large (epic) to small (task). A user story describes a need from the user's point of view.
- **Increment:** In Scrum, a usable step toward the Product Goal. Work counts as part of an increment only when it meets the Definition of Done.
- **Inner source:** Using open-source practices (open repositories, contributions across teams) inside a company.
- **ITIL:** A widely used framework of IT service management practices, covering incident, problem, and change management.
- **Kanban:** Managing work as a visual flow on a board, with limits on how much is in progress at once.
- **Lead time and cycle time:** Lead time runs from request (or commit) to production; cycle time runs from when work starts to when it's done.
- **Monte Carlo forecast:** A forecast made by simulating future work many times from the team's past throughput, giving a date or amount with a probability ("85% likely by June 3").
- **OKR (objectives and key results):** A goal-setting method: a qualitative objective, with a few measurable key results that show it's been met.
- **Platform engineering:** A team building internal tools and paved paths (an *internal developer platform*) so product teams can ship without becoming infrastructure experts.
- **Product Goal:** In Scrum, the long-term objective the Product Backlog serves. The team works toward one Product Goal at a time.
- **Product owner:** The person accountable for maximizing a product's value: setting the Product Goal and ordering the backlog. In Scrum, one person, not a committee.
- **RACI:** A responsibility chart marking who is Responsible, Accountable, Consulted, and Informed for each task.
- **Retrospective:** A regular meeting where a team inspects how it worked and chooses improvements. In Scrum, the Sprint Retrospective ends each sprint.
- **RICE:** A prioritization score from Intercom: reach × impact × confidence ÷ effort.
- **Risk register:** A list of identified risks with their likelihood, impact, owner, and plan.
- **Roadmap:** A plan of intended outcomes over time, usually by quarter.
- **Scrum:** An agile framework with fixed-length sprints, defined roles (product owner, Scrum Master, developers), and regular planning, review, and retrospective meetings.
- **Scrum master:** The person accountable for a Scrum team's effectiveness: helping it use Scrum well, coaching, and removing impediments.
- **Sprint:** A fixed period, typically two weeks, in which a team completes a set of work.
- **Sprint Goal:** The single objective for a sprint, which gives the team focus and lets it adapt the plan while still delivering value.
- **Stakeholder:** Anyone who affects or is affected by the work, such as customers, users, managers, security, and operations.
- **Team Topologies:** A model of four team types (stream-aligned, platform, enabling, complicated subsystem) and how they interact.
- **Throughput:** The number of work items a team finishes per unit of time; the basis for flow-based forecasting.
- **User story:** A backlog item written from the user's point of view: `As a <user>, I want <something>, so that <reason>.` A prompt for a conversation, not a specification.
- **Value stream:** All the steps from an idea to value delivered to the customer. Mapping it shows where work waits.
- **Velocity:** Story points a team completes per sprint. Useful only to the team itself for rough planning; misleading as a target or for comparing teams.
- **WIP (work in progress):** Work started but not finished. Limiting it shortens lead times.
- **Work item age:** How long an item in progress has been in progress. The earliest warning that work is stuck.
- **WSJF (weighted shortest job first):** A prioritization method from the Scaled Agile Framework: cost of delay divided by job size, so small, urgent, valuable work goes first.

## AWS and Azure equivalents

The closest match for each kind of service. They are rarely identical, so check the details before assuming one behaves like the other.

| Kind of service | AWS | Azure |
|---|---|---|
| Account structure | Organizations, accounts, organizational units | Management groups, subscriptions, resource groups |
| Org-wide guardrails | Service control policies (SCPs) | Azure Policy |
| Identity directory | IAM Identity Center | Microsoft Entra ID |
| Workload identity | IAM roles (instance profiles, Pod Identity, IRSA) | Managed identities, workload identity federation |
| Temporary elevated access | IAM Identity Center permission sets | Privileged Identity Management (PIM) |
| Virtual machines | EC2 | Virtual Machines |
| Scaling VM groups | Auto Scaling groups | Virtual Machine Scale Sets |
| Managed Kubernetes | EKS | AKS |
| Serverless containers | ECS on Fargate, App Runner | Container Apps, Container Instances |
| Web app hosting | Elastic Beanstalk, App Runner | App Service |
| Functions | Lambda | Azure Functions |
| Container registry | ECR | Azure Container Registry |
| Virtual network | VPC | Virtual network (VNet) |
| Network filtering | Security groups, network ACLs | Network security groups (NSGs) |
| Managed firewall | AWS Network Firewall | Azure Firewall |
| Private access to services | PrivateLink, VPC endpoints | Private Link, private endpoints |
| Layer 7 load balancer | Application Load Balancer | Application Gateway |
| Layer 4 load balancer | Network Load Balancer | Azure Load Balancer |
| CDN and global entry | CloudFront | Azure Front Door |
| DNS | Route 53 | Azure DNS |
| Dedicated private link | Direct Connect | ExpressRoute |
| Object storage | S3 | Blob Storage |
| Block storage | EBS | Managed Disks |
| File storage | EFS, FSx | Azure Files, Azure NetApp Files |
| Relational databases | RDS, Aurora | Azure Database for PostgreSQL and MySQL, Azure SQL Database |
| NoSQL | DynamoDB | Cosmos DB |
| Queue | SQS | Queue Storage, Service Bus queues |
| Pub/sub and events | SNS, EventBridge | Service Bus topics, Event Grid |
| Event streaming | Kinesis, MSK (managed Kafka) | Event Hubs |
| Secrets | Secrets Manager, Systems Manager Parameter Store | Key Vault |
| Encryption keys | KMS | Key Vault keys, Managed HSM |
| API audit log | CloudTrail | Activity log |
| Metrics, logs, alarms | CloudWatch | Azure Monitor, Log Analytics |
| Tracing | X-Ray | Application Insights |
| Security posture and threats | Security Hub, GuardDuty | Microsoft Defender for Cloud |
| Configuration history and rules | AWS Config | Azure Policy, Resource Graph change history |
| Backups | AWS Backup | Azure Backup |
| Infrastructure as code | CloudFormation, CDK | ARM templates, Bicep |
| Remote shell without SSH | Systems Manager Session Manager | Azure Bastion, Run Command |
| Cost tools | Cost Explorer, Budgets | Cost Management, budgets |
| Recommendations | Trusted Advisor, Compute Optimizer | Azure Advisor |
