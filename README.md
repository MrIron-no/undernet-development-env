UnderNET Development Environment
================================
> **Warning**
> 
> Do _**NOT**_ use this in production, it is not safe and contains publicly shared credentials! 

This repository contain a docker based development environment for UnderNET.

It includes the following services:

- hub (ircu2)
- leaf server (ircu2)
- PostgreSQL database
- Redis (Valkey) for caching and session management
- mail server (Mailpit)
- cservice web portal
- cservice API (REST API for cservice)
- GNUworld (enabled modules: cservice, ccontrol, openchanfix, dronescan, debug)


# Requirements to setup the environment

- [Docker](https://www.docker.com/)
- [docker-compose](https://docs.docker.com/compose/)


# Getting started

Source trees can come from **git submodules** and/or **existing checkouts** on your machine
(via a local `.env`). Both approaches can be mixed.

## Git Submodules

This repository includes the following submodules:

- `cservice-api/` - Go-based REST API server
- `cservice-web/` - PHP web interface
- `gnuworld/` - C++ service bot framework
- `ircu2/` - IRC server implementation
- `iauthd-c/` - IRC authorization daemon (forked by ircd)

Fetch all of them:

```
git clone https://github.com/Ratler/undernet-development-env.git
cd undernet-development-env
./scripts/init-submodules.sh
```

Or only the ones you need (skip trees you already have elsewhere):

```
./scripts/init-submodules.sh web          # cservice-web + cservice-api
./scripts/init-submodules.sh irc          # ircu2 + gnuworld + iauthd-c
./scripts/init-submodules.sh cservice-api # a single submodule by path
```

You can also pass paths directly to git:

```
git submodule update --init cservice-web cservice-api
```

## Using existing local checkouts

Copy `.env.example` to `.env` and point at your trees:

```
cp .env.example .env
```

```
IRCU2_SRC=/path/to/your/ircu2
GNUWORLD_SRC=/path/to/your/gnuworld
IAUTHD_SRC=/path/to/your/iauthd-c
# CSERVICE_WEB_SRC=/path/to/your/cservice-web
# CSERVICE_API_SRC=/path/to/your/cservice-api
```

Unset variables fall back to the submodule directories (`./ircu2`, `./gnuworld`, …).
`.env` is gitignored.

Builds use Docker Compose `additional_contexts`: the Dockerfile stays in this repo, while
the C/C++ (or other) source is taken from the path you configured.

## Optional cservice stack (api / web)

`api`, `web`, `redis`, and `mail` use the Compose profile `cservice`. They are **not**
started by a plain `docker compose up` unless that profile is active.

| How | Effect |
|-----|--------|
| `./scripts/compose.sh up -d` | Auto-enables `cservice` when both api and web sources exist (`.env` paths or initialized submodules) |
| `COMPOSE_PROFILES=cservice` in `.env` | Always start api/web/redis/mail |
| `docker compose --profile cservice up -d` | Same, one-shot |
| neither | Core only: hub, leaf, db, gnuworld |

`gnuworld` waits for `api` only when the cservice profile is running (`required: false`).

## Setup Steps

**All from submodules:**

```
git clone https://github.com/Ratler/undernet-development-env.git
cd undernet-development-env
./scripts/init-submodules.sh
./scripts/compose.sh up -d
```

**Example: local ircu2 + gnuworld only (no web/api):**

```
cp .env.example .env   # set IRCU2_SRC and GNUWORLD_SRC
./scripts/compose.sh up -d
```

**Example: local ircu2 + gnuworld, submodules for web/api:**

```
./scripts/init-submodules.sh web
cp .env.example .env   # set IRCU2_SRC and GNUWORLD_SRC
./scripts/compose.sh up -d
```

## Service information (hosts, ports and login information)

The following ports below are mapped from your host to the container:

| Service      | URL / ip:port                                        | Comments                                                                                                                                                                    |
|--------------|------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hub          | Server: localhost:4400 <br> TLS server: localhost:4440 <br> Client: localhost:6669 | The default `/oper` username is `admin` with the password `admin`. S2S links use TLS on 4440. Cert auto-generated into `etc/certs/` on first start. |
| leaf         | Server: localhost:4401 <br> TLS server: localhost:4441 <br> Client: localhost:6667 <br> TLS client: localhost:6697 <br> WebSocket: localhost:6080 <br> WSS: localhost:6443 | The default `/oper` username is `admin` with the password `admin`. Self-signed certs in `etc/certs/` (accept/ignore in your client). |
| db           | localhost:5433                                       | Host port 5433 → container 5432 (avoids clashing with a local Postgres). Default user/pass `cservice`/`cservice`. Databases: `cservice`, `ccontrol`, `chanfix`, `dronescan`, `local_db` |
| redis        | localhost:6379                                       | Valkey - used for caching and session management. No authentication required.                                                                                               |
| mail         | SMTP: localhost:1025 <br> WEB: http://localhost:8025 | Mailpit - captures e-mails from cservice-web and cservice-api, <br>e-mails can be accessed from the WEB url.                                                                |
| cservice-web | http://localhost:8080                                | Default admin (level 1000) user is `Admin` with the password `temPass2020@`                                                                                                 |
| cservice-api | http://localhost:8081                                | REST API for cservice (JWT-based authentication). Health check available at `/health-check`                                                                                 |


# Configuration

The configuration for the `hub`, `leaf` and `gnuworld` can be changed in the folder `etc/`.
All the files are mounted inside the container as volumes, so any change done on your host
is reflected in the container immediately. For example after changing `etc/hub.conf`, just 
`/rehash` the IRC server to apply the changes.

For the service `cservice-web` the configuration can be changed from `cservice-web/php_includes`. Any configuration
or code change will be applied immediately.

# Making code changes in ircu, gnuworld or cservice-api

After changing ircu, gnuworld or cservice-api, rebuild and restart the service.

Rebuild ircu (hub and leaf share the same image):
```
docker compose up --build hub
docker compose up leaf
```

Rebuild and restart gnuworld:
```
docker compose up --build gnuworld
```

Rebuild and restart cservice-api (requires the `cservice` profile):
```
docker compose --profile cservice up --build api
```

For cservice-web, changes under `cservice-web` are reflected immediately (bind mount).

## IAuth (iauthd-c)

[iauthd-c](https://github.com/UndernetIRC/iauthd-c) is **not** a separate Compose
service. ircd forks `/opt/iauthd/libexec/iauthd-c` over stdin/stdout when an
`IAuth { ... }` block is present (see `etc/leaf.conf` and `etc/hub.conf`).

- Binary + modules are built into the `ircu2` image (additional context `iauthd`)
- Runtime config is bind-mounted from `etc/iauthd-c.conf`
- Source path: submodule `./iauthd-c` or `IAUTHD_SRC` in `.env`

After changing iauthd-c sources, rebuild the ircu image (`docker compose up --build hub`).
Config-only edits: remount is live after `/rehash` on the IRC server (ircd respawns iauth).

## Incremental C++ builds (ircu2 / gnuworld)

`Dockerfile.ircu2` and `Dockerfile.gnuworld` use BuildKit cache mounts for the
work tree and `ccache`. On rebuild after a code edit:

- `./autogen.sh` runs only when `configure.ac` / `Makefile.am` changed
- `./configure` runs only when configure inputs or flags changed
- `make` only recompiles what is stale (plus ccache for repeated compiles)

First build is still a full compile. Later `docker compose up --build …` after
editing a `.cc` file should be much faster. To wipe the caches and force a clean
build: `docker builder prune` (or delete the `undernet-*-work` / `*-ccache`
cache mounts).

# IRC Client Simulator

The `sim/` directory contains a Python-based IRC client simulator that can spin up many concurrent clients to generate realistic traffic on the development network. It provisions user accounts and channels directly in the database and simulates chat, channel operations (op/deop/voice/kick), and authentication with X.

## Quick start

```
cd sim
uv sync
uv run undernet-sim --authenticated-users 20 --unauthenticated-users 10 --registered-channels 4 --unregistered-channels 5
```

Requires [uv](https://docs.astral.sh/uv/) and Python 3.11+. See `sim/README.md` for full documentation and CLI options.

# PostgreSQL databases

## Data persistence

All databases are persisted by using a docker volume. To list existing volumes  run `docker volume ls`. 
To reset all databases you can delete the volume by running `docker volume rm undernet-development-env_pgdata`,
and then restart the `db` service to recreate all databases.


# FAQ
Q: Why do I see this message _"X (cservice@undernet.org): AUTHENTICATION FAILED as <user> 
   (Unable to login during reconnection, please try again in 295 seconds)"_ when trying to 
   authenticate with `x@channels.undernet.org`?

A: This is a burst connection mechanism in GNUworld which happen when it links to its hub. 
   Just wait for it to complete and try again. Or you can change the setting `login_delay` in
   `etc/gnuworld/cservice.conf`, it's currently set to 5 seconds.

