# Quickstart: verify readiness against a real database (SC-002)

The gate never needs SQL Server (spec SC-001); this is the by-hand check that readiness works
against the real LocalDB database. It is one-time local setup, not schema: no table is created
(feature 001 has no tables and no migrations).

All commands run from the repository root in PowerShell.

## 1. Create the empty, dedicated database (once)

Database rulebook, Setup: the database must be dedicated to booking-api. Confirm LocalDB holds
no other database by that name first:

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "SELECT name FROM sys.databases WHERE database_id > 4"
```

If `BookingApi` is not listed, create it:

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "CREATE DATABASE BookingApi"
```

## 2. Store the connection string as a user secret (once)

Never in `appsettings*.json` (spec FR-008):

```powershell
dotnet user-secrets set "ConnectionStrings:BookingApi" "Server=(localdb)\MSSQLLocalDB;Database=BookingApi;Trusted_Connection=True;Connect Timeout=5;TrustServerCertificate=True" --project src/BookingApi.Api
```

## 3. Run the API

```powershell
dotnet run --project src/BookingApi.Api --launch-profile http
```

It listens on `http://localhost:5132` in the Development environment.

## 4. Verify (second terminal)

Liveness, always 200 `Healthy`:

```powershell
curl.exe -i http://localhost:5132/health
```

Readiness with the database up, expect `200` and the body `Healthy`:

```powershell
curl.exe -i http://localhost:5132/health/ready
```

Readiness with the database unreachable. LocalDB restarts itself on the next connection, so
stopping LocalDB does not make the database unreachable; take the database offline instead:

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "ALTER DATABASE BookingApi SET OFFLINE WITH ROLLBACK IMMEDIATE"
curl.exe -i -w "`ntime: %{time_total}s`n" http://localhost:5132/health/ready
```

Expect `503`, the body `Unhealthy`, a total time under 5 seconds, and no connection string,
server name or exception text in the response. Liveness (`/health`) must still answer `200`.

Bring it back and confirm readiness recovers (`200`):

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "ALTER DATABASE BookingApi SET ONLINE"
curl.exe -i http://localhost:5132/health/ready
```

## 5. Other checks in Development

- `http://localhost:5132/openapi/v1.json` returns the OpenAPI document and lists `/health`.
- Any unknown route, for example `/nope`, returns a `404` `application/problem+json` body.

## Clean up (optional)

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "DROP DATABASE BookingApi"
dotnet user-secrets remove "ConnectionStrings:BookingApi" --project src/BookingApi.Api
```
