# Valkey LDAP demo

A demo showing how to configure Valkey authentication with LDAP using the `valkey-ldap` module.

This demo runs one Valkey Bundle container with the LDAP authentication module and
two OpenLDAP containers seeded with test users.

## Demo topology

| Service | Container | Purpose |
| --- | --- | --- |
| `valkey` | `v1` | Valkey Bundle with the LDAP module |
| `ldap-1` | `ldap-1` | Primary LDAP server |
| `ldap-2` | `ldap-2` | Secondary LDAP server for HA testing |

LDAP base DN:

```text
dc=valkey,dc=io
```

## Step 1: Start the demo environment

Start the containers:

```bash
docker compose up -d
```

This starts:

- 02 OpenLDAP containers with users and OUs defined in [users.ldif](./ldap/users.ldif)
- 01 Valkey Bundle container running officially supported modules (JSON, Search, Bloom, and LDAP)

## Step 2: Create Valkey users

Open a `valkey-cli` session in the `v1` container, starting in RESP 3 mode (using `-3` flag) so that the commands output are more visually identifiable:

```bash
docker exec -ti v1 valkey-cli -3
```

Create the two users `user1` and `u2` using `ACL SETUSER`, setting the `resetpass` flag so that they cannot be authenticated using passwords stored inside the Valkey instance:

```valkey
ACL SETUSER user1 on resetpass +@all ~*
ACL SETUSER u2 on resetpass +@all ~*
```

Verify that the users are created:

```valkey
ACL LIST
```

Expected output:

```plaintext
1) "user default on nopass sanitize-payload ~* &* alldbs +@all"
2) "user u2 on sanitize-payload ~* resetchannels alldbs +@all"
3) "user user1 on sanitize-payload ~* resetchannels alldbs +@all"
```

## Step 3: Configure Valkey connection to LDAP

Inside `valkey-cli`, point the LDAP module at both LDAP servers:

```text
CONFIG SET ldap.servers "ldap://ldap-1:389 ldap://ldap-2:389"
```

## Step 4: Authenticate using bind mode

Configure bind mode:

```valkey
CONFIG SET ldap.auth_mode bind
CONFIG SET ldap.bind_dn_prefix "cn="
CONFIG SET ldap.bind_dn_suffix ",ou=devops,dc=valkey,dc=io"
```

Bind mode works when Valkey can construct the LDAP DN directly from the username
sent in `AUTH`. The Disinguish Name (DN) sent to LDAP server(s) will be created by simple string concatenation following the format:

```plaintext
${ldap.bind_dn_prefix}${username}${ldap.bind_dn_suffix}
```

With the above configurations, `user1`'s DN will be:

```plaintext
cn=user1,ou=devops,dc=valkey,dc=io
```

Verify that the configuration is working by authenticate as `user1`:

```valkey
AUTH user1 user1@123
ACL WHOAMI
```

Expected result:

```text
"user1"
```

## Step 5: Authenticate using bind+search mode

Search+bind mode works when the login name is an LDAP attribute, not a simple DN
component. In this demo, the LDAP entry is:

```text
dn: cn=user2,ou=appdev,dc=valkey,dc=io
uid: u2
userPassword: user2@123
```

Configure search+bind mode:

```text
CONFIG SET ldap.auth_mode "search+bind"
CONFIG SET ldap.search_bind_dn "cn=admin,dc=valkey,dc=io"
CONFIG SET ldap.search_bind_passwd "admin123!"
CONFIG SET ldap.search_base "dc=valkey,dc=io"
CONFIG SET ldap.search_filter "objectClass=*"
CONFIG SET ldap.search_attribute "uid"
CONFIG SET ldap.search_scope "sub"
CONFIG SET ldap.search_dn_attribute "entryDN"
```

Test authentication with the `uid` value:

```valkey
AUTH u2 user2@123
ACL WHOAMI
```

Expected result:

```text
"u2"
```

## Step 6: LDAP connection High Availability

The module accepts multiple LDAP URLs in `ldap.servers`. It maintains connection
pools and uses a failure detector to mark an LDAP server unhealthy, then routes
authentication to another available LDAP server.

Confirm both LDAP servers are configured:

```valkey
CONFIG GET ldap.servers
```

Expected output:

```plaintext
1# "ldap.servers" => "ldap://ldap-1:389 ldap://ldap-2:389"
```

Check LDAP health from Valkey:

```valkey
INFO ldap_status
```

Expected output:

```plaintext
# ldap_status
ldap_server_0:host=ldap-1,status=healthy,ping_time_ms=2.026
ldap_server_1:host=ldap-2,status=healthy,ping_time_ms=1.98
```

Stop the first LDAP server:

```bash
docker compose stop ldap-1
```

Give the failure detector a moment, then check status again:

```bash
docker compose exec valkey valkey-cli INFO ldap_status
```

Expected output:

```plaintext
# ldap_status
ldap_server_0:host=ldap-1,status=unhealthy,error=LDAP connection failure: I/O error: failed to lookup address information: Name or service not known
ldap_server_1:host=ldap-2,status=healthy,ping_time_ms=3.039
```

Authenticate again. This should still succeed through `ldap-2`:

```bash
docker compose exec valkey valkey-cli --user u2 --pass 'user2@123' PING
```

Start `ldap-1` again:

```bash
docker compose start ldap-1
```

Check that both endpoints return to service:

```bash
docker compose exec valkey valkey-cli INFO ldap_status
```

## Step 7: Get LDAP authentication error on `AUTH` attempt

By default, when there is an authentication issue, Valkey will return the generic `WRONGPASS` error:

```valkey
AUTH user1 hello
```

```plaintext
(error) WRONGPASS invalid username-password pair or user is disabled.
```

And the LDAP error will appear in the Valkey server's log:

```bash
docker compose logs -f valkey
```

Expected output:

```log
1:M 01 Oct 2026 08:24:26.161 * Ready to accept connections tcp
1:M 01 Oct 2026 08:25:13.907 # <ldap> LDAP authentication failure: error in bind operation: LDAP operation result: rc=49 (invalidCredentials), dn: "", text: ""

```

Set the config `ldap.return_auth_errors` to `yes` to get the LDAP error message rather than the default `WRONGPASS`

```valkey
CONFIG SET ldap.return_auth_errors yes
```

Authenticate using the wrong password again:

```valkey
AUTH user1 hello
```

Expected output:

```plaintext
(error) ERR error in bind operation: LDAP operation result: rc=49 (invalidCredentials), dn: "", text: ""
```

**Note**: Setting `ldap.return_auth_errors` to `yes` will stop the authentication chain. See the [Using `valkey-ldap` in a deployment with multiple authentication modules](./multi-auth-modules-demo/README.md) demo for more detail.

## Step 8: Cleanup

Stop and remove the demo containers:

```bash
docker compose down
```

## References

- [Valkey LDAP authentication](https://valkey.io/topics/ldap/)
- [valkey-ldap module](https://github.com/valkey-io/valkey-ldap)
