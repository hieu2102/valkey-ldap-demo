#!/bin/bash

set -euo pipefail

ADMIN_DN="cn=admin,${LDAP_BASE_DN}"
USER1_DN="cn=user1,ou=devops,${LDAP_BASE_DN}"

# wait for LDAP service to start
CHECK_OUTPUT="$(ldapwhoami -x -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" 2>/dev/null || true)"

while [[ "${CHECK_OUTPUT}" != "dn:${ADMIN_DN}" ]]; do
    sleep 3
    CHECK_OUTPUT="$(ldapwhoami -x -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" 2>/dev/null || true)"
done

# check if users already exist
if ldapsearch -x -LLL \
    -D "${ADMIN_DN}" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -b "${USER1_DN}" \
    -s base \
    dn >/dev/null 2>&1; then
    echo "LDAP demo users already exist; skipping seed data."
    exit 0
fi

ldapadd -x -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" -f /opt/ldap/users.ldif
