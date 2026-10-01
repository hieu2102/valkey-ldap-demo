# Using valkey-ldap in a deployment with multiple authentication modules

A demo showing how `valkey-ldap` module works in a deployment with multiple authentication modules.

This demo runs 01 modified Valkey Bundle container with the [`testacl`](https://github.com/valkey-io/valkey/blob/unstable/tests/modules/auth.c) module, and 01 OpenLDAP container.

## Demo topology

| Service | Container | Purpose |
| --- | --- | --- |
| `valkey` | `v2` | modified Valkey Bundle container, built using `multi-auth.Dockerfile` |
| `ldap` | `ldap` | LDAP server |

## Step 1: Start the demo environment

```bash
docker compose up -d
```

This starts:

- 01 OpenLDAP containers with users and OUs defined in [users.ldif](./ldap/users.ldif)
- 01 modified Valkey Bundle running the `valkey-ldap` module and the [`testacl` module from `valkey` GitHub repository](https://github.com/valkey-io/valkey/blob/unstable/tests/modules/auth.c)

## Step 2: Create the Valkey user

Start a `valkey-cli` session in the `v2` container:

```bash
docker compose exec valkey valkey-cli
```

Create the user `foo` without specifying a local password:

```valkey
ACL SETUSER foo on resetpass +@all ~*
```

## Step 3: Load the authentication modules

```valkey
MODULE LOAD /usr/lib/valkey/libvalkey_ldap.so
MODULE LOAD /usr/lib/valkey/libauth.so
```

## Step 4: Configure bind mode authentication for `valkey-ldap` module

```valkey
CONFIG SET ldap.servers ldap://ldap:389
CONFIG SET ldap.auth_mode bind
CONFIG SET ldap.bind_dn_prefix "cn="
CONFIG SET ldap.bind_dn_suffix ",ou=devops,dc=valkey,dc=io"
```

## Step 5: Enable the `testacl` module authentication callback function

```valkey
TESTMODULEONE.RM_REGISTER_AUTH_CB
```

## Step 6: Authenticate as user `foo` using the LDAP password

Authenticate as user `foo`, using the password specified in `users.ldif` file:

```valkey
AUTH foo foo@123
```

Expected output:

```plaintext
OK
```

## Step 7: Authenticate as user `foo` using hard-coded password by `testacl` module

Authenticate as user `foo` again, this time with the password hard-coded into the [`testacl` module](https://github.com/valkey-io/valkey/blob/unstable/tests/modules/auth.c#L97).
The authentication attempt is successful, due to `testacl` registers that `allow` is the correct password for user `foo`:

```valkey
AUTH foo allow
```

Expected output:

```plaintext
OK
```

## Step 8: Stop the authentication chain at `valkey-ldap` with `ldap.return_auth_errors`

Set the config `ldap.return_auth_errors` to `yes`:

```valkey
CONFIG SET ldap.return_auth_errors yes
```

Authenticate as user `foo` using the password `allow`:

```valkey
AUTH foo allow
```

Expected output:

```plaintext
(error) ERR error in bind operation: LDAP operation result: rc=49 (invalidCredentials), dn: "", text: ""
```

This is due to `valkey-ldap` being loaded before `testacl`. So by setting `ldap.return_auth_errors` to `yes`, which will send the error code `VALKEYMODULE_AUTH_HANDLED` (indicate that the authentication attempt is handled by the `valkey-ldap` module) to the `valkey-server` process, thus stopping the authentication chain.

## Step 9: Cleanup

Stop and remove the demo containers:

```bash
docker compose down
```
