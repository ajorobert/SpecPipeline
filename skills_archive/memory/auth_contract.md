# Auth Contract

Project-specific auth shapes. Skills reference this; do not duplicate in skills.

## Realm claims (Keycloak)
```ts
type RealmClaims = {
  sub: string;
  // fill: additional claims as confirmed against realm config
};
```

## Session shapes
```ts
type PortalSession = { /* fill 6f */ };

type AdminSession = {
  isAuthenticated: boolean;
  userId:          string;                      // from sub claim
  roles:           string[];                    // from realm_access.roles; drives role-based UI
  accessTokenExpiresAt: number;                 // epoch seconds; used by apiClient updateToken threshold
  // claim names below are project-specific — confirm against realm config before relying on them
  email?:    string;                            /* unknown — confirm with team */
  fullName?: string;                            /* unknown — confirm with team */
  tenantId?: string;                            /* unknown — confirm with team (custom claim?) */
};

type MobileSession = {
  isAuthenticated:      boolean;
  userId:               string;                  // from sub claim
  roles:                string[];                // from realm_access.roles; drives role-based UI affordances
  accessTokenExpiresAt: number;                  // epoch seconds; used by apiClient + AppState foreground refresh
  // claim names below are project-specific — confirm against realm config before relying on them
  email?:    string;                             /* unknown — confirm with team */
  fullName?: string;                             /* unknown — confirm with team */
  tenantId?: string;                             /* unknown — confirm with team (custom claim?) */
};
```

## Token storage
| Surface   | Access                                                          | Refresh                                                          |
|---|---|---|
| Portal    | fill 6f                                                         | fill 6f                                                          |
| Admin SPA | in-memory only (keycloak-js instance); never localStorage/sessionStorage | in-memory only (keycloak-js instance); silent SSO via OIDC `prompt=none` on reload |
| Mobile    | in-memory only; never persisted                                 | `expo-secure-store` (iOS Keychain / Android Keystore); never AsyncStorage; never MMKV |
