# Autovella platform audit

Findings from building a full mobile client against the live API
(`autovella.cloud/api`) and testing it on a real Android device. Everything
below is a **platform-side** issue: the mobile app has been worked around it
where possible, but the fix belongs in the backend or the web client.

Evidence is from three sources: live API probes, the web app's own JavaScript
bundles (`/assets/dist/chunks/*.js` — the authoritative client), and real
payloads pulled through the MCP surface.

---

## 1. Avatars are inlined as base64 on list endpoints — *severe*

Several endpoints embed each user's avatar as a `data:image/jpeg;base64,…`
string, roughly **190–200 KB per user**, inside ordinary list responses.

Measured:

| Endpoint | Rows | Payload |
|---|---|---|
| `/auth/me` | 1 user | **202 KB** (the avatar is 99% of it) |
| `/auth/users` | 3 users | **570 KB** |
| `/audit-logs` | 2 entries | **406 KB** |

At the documented `limit` maximum of 100, `/auth/users` is roughly **19 MB**
and `/audit-logs` roughly **20 MB** — for a screen showing names and dates.

**Impact.** On mobile data this is the difference between a screen that loads
and one that does not. It is why the app's People screen appeared blank and
the audit log would not open. It also slows every web page that reads a user
list, and inflates the cost of the MCP surface, where a single `whoami` call
overflows a 200 KB tool-output budget.

**Fix.** Serve avatars as URLs (`/files/avatars/<id>.jpg`) and return the URL
in JSON. Cache them at the CDN. If inline images must stay for a legacy
client, gate them behind an explicit `?include=avatar` parameter so the
default response is small.

**Workaround shipped.** Mobile uses `/auth/users/directory` for People, caps
the audit log at 25 rows, and renders initials rather than decoding data-URI
avatars.

---

## 2. Unknown routes answer HTTP 500, not 404

```
GET /api/zzz-does-not-exist   →  500  {"success":false,"message":"Server Error"}
```

A missing route is a client error, not a server failure. Returning 500 means
genuine outages are indistinguishable from typos, monitoring cannot separate
them, and integrators cannot tell "wrong URL" from "your server is broken".

**Fix.** A terminal 404 handler on the API router.

---

## 3. There is no logout endpoint

The web client signs out purely by discarding the token client-side
(`clearAuth()`); there is no `POST /auth/logout`, and no revocation list.

**Impact.** A token captured from a device stays valid until it expires, even
after the user "signs out". On a shared or lost phone that is a real exposure.

**Fix.** A logout endpoint that revokes the presented token server-side, plus
a "sign out of all devices" action.

---

## 4. No push notification infrastructure

There is no endpoint to register a device token, so neither FCM (Android) nor
APNs (iOS) can be wired up. Notifications can only be delivered while the app
is running.

**Fix.** `POST /notifications/devices {token, platform}` plus server-side fan-out
on the events that already create in-app notifications.

---

## 5. Response envelope is inconsistent

Most endpoints answer `{success, data}`. At least one does not:

```
/notifications/unread-count  →  {"success": true, "count": 7}
```

Clients must special-case it. Standardise on `{success, data}` for everything.

---

## 6. `/approvals` does not exist as an endpoint

The web app has an Approvals page, but it is a composite assembled client-side
over `/timesheets`, `/time-off` and `/expenses`, each with its own
`/:id/approve` and `/:id/reject`. Every client has to re-implement the same
fan-out, merge and sort.

**Fix.** A read-only `GET /approvals` returning the merged queue.

---

## 7. Field naming is inconsistent across resources

| Concept | Varies as |
|---|---|
| Amount paid | `paidAmount` (invoices) vs `amountPaid` (elsewhere) |
| Due date | `endDate` (tasks) vs `dueDate` (projects, invoices) |
| Invoice lines | split across `customItems`, `timeEntries`, `expenseEntries` — no unified `lineItems` |
| Deleted-by | `deletedBy` is an **id**, `deletedByName` is the name — elsewhere `createdBy` is an **object** |

Each inconsistency is a bug waiting to happen in every new client. The mobile
app now accepts several spellings per field defensively, which works but
should not be necessary.

---

## 8. The web route and API route for audit log disagree

Web route is `/audit-log` (singular); the API is `/audit-logs` (plural). The
singular API path returns 500. This cost real debugging time and is the kind
of mismatch that will keep costing it.

---

## 9. Attendance punch does not return the updated record

`POST /attendance/punch {type:"auto"}` answers with a message only, so every
client must immediately re-fetch `/attendance/me/today` to redraw. Returning
the updated record would halve the round trips on the most frequently used
action in the product.

---

## 10. Modules that exist in the UI but not in the API

`/leads`, `/customers`, `/vehicles`, `/inventory` and `/resources` are **not**
API routes. `ResourcePlanner` exists as a web module but is served from
`/projects/resource-planner` and `/task-schedules`, not `/resources`.

Worth confirming whether Leads and Customers are intended roadmap items or
dead references — they appear in the web bundle's route strings but have no
backing endpoint.

---

## 11. `/saved-views` rejects a request with no `entityType`

```
GET /saved-views  →  "Invalid entityType"
```

There is no default and no way to list a user's saved views across entities.
Every client must know to ask per entity type. Either default to all, or
document the parameter as required and return a 400 that says so.

---

## 12. Role names are stored HTML-escaped

One role in the demo org is literally named `Sales &amp; Business Development`
in the database — the ampersand was escaped on write, not on render. Any
client that does not decode entities shows the raw `&amp;`.

**Fix.** Escape on output, never on input. Worth a data migration to find
other `&amp;` / `&lt;` occurrences in stored names and descriptions.

---

## 13. Field-level permissions exist but are undocumented

Roles carry per-field grants:

```json
"tasks": { "read": true, "fields": { "estimatedHours": {"read": true, "edit": true} } }
```

This is a genuinely good feature and a real differentiator — but it is not
described anywhere a client author would find it, so every client that does
not implement it will over-expose fields to restricted roles. The mobile app
does **not** yet honour field-level grants; it respects module-level CRUD only.

**Fix.** Document the shape, and ideally enforce it server-side on read so a
naive client cannot leak a field it was not meant to show.

---

## 14. Role sprawl and duplicated system roles

The demo org carries both the built-in system roles (`admin`, `employee`,
`manager`, `finance`, `contractor`, `customer`, with `organizationId: null`)
**and** org-level roles with the identical names. It also has several
near-duplicates:

- `DevOps / SRE` vs `DevOps Engineer` vs `Cloud/SRE Engineer`
- `QA / Tester` vs `QA Engineer / Tester`
- `Sales & Business Development` vs `Sales/BD/Marketing`
- `HR` vs `HR / People Ops`

Some of the duplicates have `permissions: {}` — an empty grant — so assigning
one silently removes a user's access. That is a sharp edge worth a tidy-up and
a guard against creating a role with no permissions at all.

---

## Priority

| # | Issue | Severity | Effort |
|---|---|---|---|
| 1 | Base64 avatars in list payloads | High | Low |
| 3 | No token revocation on logout | High | Medium |
| 2 | 500 instead of 404 | Medium | Trivial |
| 4 | No push infrastructure | Medium | Medium |
| 7 | Field-naming inconsistency | Medium | Medium |
| 6 | No `/approvals` aggregate | Low | Low |
| 5 | Envelope inconsistency | Low | Trivial |
| 8 | audit-log vs audit-logs | Low | Trivial |
| 9 | Punch does not return record | Low | Trivial |
| 10 | Phantom modules | Low | Investigation |
| 13 | Field-level permissions undocumented / not enforced | High | Medium |
| 12 | HTML-escaped data in the database | Medium | Low |
| 14 | Duplicate roles, some with empty permissions | Medium | Low |
| 11 | `/saved-views` needs undocumented `entityType` | Low | Trivial |
