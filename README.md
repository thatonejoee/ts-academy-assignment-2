# Dockerized Diagnostic CLI

A small Bash command-line tool that reports system, network and disk
information, packaged as a lightweight Docker image. Built for the DevOps
practical, Assignment 2.

Author: Joseph Fatoke

## Project layout

| Path | Purpose |
|------|---------|
| `app/diagnostic.sh` | The CLI (`system`, `network`, `disk`, `help`) |
| `app/health-check.sh` | Verifies the tool is installed and working (used by `HEALTHCHECK`) |
| `Dockerfile` | Builds the image from Alpine Linux |
| `compose.yaml` | Runs the tool with Docker Compose |
| `.dockerignore` | Keeps `.git`, logs and local files out of the build context |
| `test.sh` | Test suite for the image |
| `grade.sh` | Instructor-supplied grading script |

## Installation / Setup

Requirements: Linux, Docker Engine, and the Docker Compose plugin.

```bash
git clone <repository-url>
cd <repository>
chmod +x grade.sh test.sh app/*.sh
docker build -t diagnostic-tool .
```

## Usage

```bash
docker run --rm diagnostic-tool help
docker run --rm diagnostic-tool system
docker run --rm diagnostic-tool disk
docker run --rm diagnostic-tool network example.com
```

With Docker Compose:

```bash
docker compose run --rm diagnostic system
docker compose run --rm diagnostic network localhost
```

Without Docker (for development):

```bash
./app/diagnostic.sh system
```

### Commands

| Command | Description |
|---------|-------------|
| `system` | Hostname, user, date/time, OS, kernel, architecture, uptime, CPU, memory |
| `network <host>` | Validates the host, resolves it, and tries a ping |
| `disk [path]` | Disk usage for a path (default `/`) |
| `help` | Shows commands and usage |

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Operational failure (for example, the host does not resolve) |
| 2 | Invalid command or input (unknown command, missing or malformed argument) |

## Testing

```bash
./test.sh            # builds the image and tests it
./test.sh --local    # tests app/diagnostic.sh directly, without Docker
./grade.sh           # instructor's grading script
```

`test.sh` covers `help`, `system`, `disk`, `network`, and invalid input
(unknown command, no command, missing argument, malformed host, extra
arguments), and checks both output and exit codes.

## Design notes

- **Base image:** `alpine:3.20`, with only `bash` and `musl-utils` added.
- **Non-root:** the container runs as an unprivileged `appuser`.
- **Portability:** the scripts read `/proc` and `/etc/os-release` instead of
  relying on tools that differ between Alpine (busybox) and Ubuntu.
- **Build context:** only `app/` is copied into the image; `.dockerignore`
  excludes everything else.
- **Compose:** the service runs with a read-only filesystem and
  `no-new-privileges`.

## Assumptions

- Docker and the Compose plugin are installed on the machine that runs the
  tests.
- `network` succeeds when the host resolves. A missing ping reply is reported
  but does not fail the command, because ICMP is often blocked in containers
  and on restricted networks.
- Resolving public hostnames needs internet access; `localhost` always works.
- No secrets are stored in the repository.
