# AGENTS.md - backend

Backend-specific guidance for MedVision.

## Runtime

- Use plain JavaScript modules for shared logic so local tests can run with Node.
- Keep Supabase deployment-specific code under `supabase/functions/`.
- Do not commit secrets or `.env` files.

## Scope

- Backend owns OCR proxying, medicine parsing, data persistence, and drug-info proxying.
- Keep user data isolated with RLS-oriented schema design.
- Match API field names to the existing Swift app where practical.

## Commands

```bash
# Run backend unit tests
npm --prefix backend test
```

## Testing

- Write tests first for parsing, validation, and normalization logic.
- Prefer pure functions in `backend/src/` for anything that can be tested without Supabase services.
