# Using valkey-ldap in a deployment with multiple authentication modules

A demo showing how `valkey-ldap` module works in a deployment with multiple authentication modules.

This demo runs 1 Valkey Bundle container, 1 modified Valkey Bundle container with the [`testacl`](https://github.com/valkey-io/valkey/blob/unstable/tests/modules/auth.c) module, and 1 OpenLDAP container.

## Demo topology

| Service | Container | Purpose |
| --- | --- | --- |
| `valkey-1` | `v1` | unmodified Valkey Bundle container |
| `valkey-2` | `v2` | modified Valkey Bundle container, built using `multi-auth.Dockerfile` |
| `ldap` | `ldap` | LDAP server |

## Prerequisites

- Docker and Docker Compose

## Step 1: Build the modified Valkey Bundle image

```bash
docker build -f multi-auth.Dockerfile -t valkey-ldap-demo:multi-auth .
```
