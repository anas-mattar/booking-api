# booking-api

A booking/reservation REST API: resources, time slots, and bookings.
.NET 10 ASP.NET Core Web API on SQL Server.

## Build and test (the gate)

From the repository root (PowerShell):

```powershell
dotnet build BookingApi.slnx --warnaserror && dotnet test BookingApi.slnx --no-build
"EXIT: $LASTEXITCODE"
```

`docs/sdlc/gate-command.md` has the other shells and explains who certifies the gate.

## How work is delivered

This repository is governed by the agentic-sdlc-kit (`.kit-version`, `kit-adoption.json`):

- Constitution: `.specify/memory/constitution.md`
- Agent entry point: `CLAUDE.md`
- Domain invariants: `docs/domain/booking-invariants.md`
- The whole workflow on one page: `docs/sdlc/flow.md`
- What to spec next: `docs/roadmap.md`

Ritual checks (the same command CI runs): `pwsh -File scripts/ritual-checks.ps1`.
Adoption health: `pwsh -File scripts/verify-kit.ps1`.
Pulling kit updates: `adoption/updating.md`.
