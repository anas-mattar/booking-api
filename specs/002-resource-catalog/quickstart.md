# Quickstart: apply the migration and use the Resource Catalog by hand (SC-005)

The gate proves everything on throwaway SQL Server containers (it needs Docker and never
touches your LocalDB database). This is the by-hand check on the real local database
`BookingApi`: the migration applies, the API creates and lists resources, and the table and its
constraints are what `data-model.md` says. It follows `quickstart.md` of feature 001 (the
database and the user secret already exist).

All commands run from the repository root in PowerShell 7 (the `curl.exe` JSON bodies rely on
its native-argument quoting; Windows PowerShell 5.1 needs the quotes inside them backslash-escaped).

## 1. Apply the migration with the pinned tool

Database rulebook, Setup: confirm the target is the dedicated `BookingApi` database first.

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "SELECT name FROM sys.databases WHERE database_id > 4"
dotnet tool restore
dotnet ef database update --project src/BookingApi.Infrastructure
```

The design-time factory targets `(localdb)\MSSQLLocalDB`, database `BookingApi`, unless the
`BOOKINGAPI_CONNECTION` environment variable is set. The application itself never migrates on
startup. Expect `Applying migration '..._ResourceCatalog'` and `Done.`

## 2. Run the API

```powershell
dotnet run --project src/BookingApi.Api --launch-profile http
```

It listens on `http://localhost:5132` (Development, so `/openapi/v1.json` is served too).

## 3. Create, get and list

In a second PowerShell window (`curl.exe`, not the `curl` alias):

```powershell
curl.exe -i -X POST http://localhost:5132/resources -H "Content-Type: application/json" -d '{"name":"Room A","description":"Ground floor, seats 8"}'
curl.exe -i http://localhost:5132/resources/<id>
curl.exe -i http://localhost:5132/resources
curl.exe -i "http://localhost:5132/resources?page=1&pageSize=1"
```

Expect `201 Created` with `Location: /resources/<id>` (`1` on an empty table; use the id you got in
place of `<id>` below) and a body with `id`, `name`, `description`,
`createdAtUtc` and `updatedAtUtc` (instants end in `Z`); `200` for the get; `200` with
`items`, `page`, `pageSize` and `totalCount` for the lists.

Then the refusals, each `application/problem+json`:

```powershell
curl.exe -i -X POST http://localhost:5132/resources -H "Content-Type: application/json" -d '{"name":" room a "}'
curl.exe -i -X POST http://localhost:5132/resources -H "Content-Type: application/json" -d '{"name":"   "}'
curl.exe -i http://localhost:5132/resources/999
curl.exe -i http://localhost:5132/resources/abc
curl.exe -i "http://localhost:5132/resources?page=0&pageSize=abc"
```

Expect `409` (title `Resource name already in use`), `400` naming `name`, `404`, `404`, and `400`
naming both `page` and `pageSize`.

## 4. Verify the table and its constraints (SC-005)

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -d BookingApi -E -Q "SELECT Id, Name, Description, CreatedAtUtc, CreatedBy, IsDeleted FROM Resources"
sqlcmd -S "(localdb)\MSSQLLocalDB" -d BookingApi -E -Q "SELECT name FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('Resources'); SELECT name, is_unique, filter_definition FROM sys.indexes WHERE object_id = OBJECT_ID('Resources') AND name = 'IX_Resources_Name'"
```

Expect the row from step 3 (`CreatedBy` is `anonymous`), the three check constraints
`CK_Resources_Name_Trimmed`, `CK_Resources_Deleted_Consistent` and
`CK_Resources_Updated_NotBeforeCreated`, and the unique index `IX_Resources_Name` filtered on
`[IsDeleted] = 0`. The database itself refuses what the API would have: this insert must fail
with a check-constraint violation.

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -d BookingApi -E -Q "INSERT INTO Resources (Name, CreatedAtUtc, CreatedBy, UpdatedAtUtc, UpdatedBy) VALUES (N' padded ', SYSUTCDATETIME(), 'x', SYSUTCDATETIME(), 'x')"
```

## 5. Optional: reverse the migration

Only while the table is empty (data-model.md, Migration; `rollback.md`). With data in it, do not:
leave the table.

```powershell
dotnet ef database update 0 --project src/BookingApi.Infrastructure
```
