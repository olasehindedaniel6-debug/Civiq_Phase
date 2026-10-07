# Roles and scopes

CIVIQ uses **area-scoped roles**. A role is never just "admin"; it is
"admin *of this area*". Areas form a hierarchy (see architecture), and a role
granted on an area applies to that area **and everything below it**.

```
Owner                (platform-wide, the project founder)
 └─ Super admin      (e.g. Nigeria)      controls all states/cities below
     └─ Admin        (e.g. Oyo State)    controls all cities/districts below
         └─ Moderator (e.g. Ibadan)      reviews incidents in this city
```

Rules:
1. A role assignment = (user, role, area). Owner is the only global role.
2. Permission check: the target resource's area must be the assigned area
   or a descendant of it. Enforced server-side on every request.
3. A user may only grant roles lower than their own, and only within their own scope.
4. Deny by default. Every grant/revoke is written to the audit log.
5. Citizens need no area-scoped admin role and can report anywhere.

Status: DESIGNED. Implemented in Phase 2 (tables) and Phase 3 (enforcement).
