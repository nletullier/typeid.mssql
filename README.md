# TypeId T-SQL (SQL Server)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![SQL Server 2025](https://img.shields.io/badge/SQL%20Server-2025%20(compat%20170)-CC2927.svg)](https://learn.microsoft.com/sql/sql-server/)
[![Pure T-SQL](https://img.shields.io/badge/Pure-T--SQL-blue.svg)](sql/)
[![TypeId spec](https://img.shields.io/badge/spec-TypeId-brightgreen.svg)](https://github.com/jetify-com/typeid)

A pure T-SQL implementation of [TypeId](https://github.com/jetify-com/typeid),
targeting **SQL Server 2025**.

A **TypeId** is a modern, type-safe identifier: a human-readable prefix, an
underscore, and a [UUIDv7](https://www.rfc-editor.org/rfc/rfc9562) rendered in
Crockford base32. For example:

```
user_01h455vb4pex5vsknk084sn02q
└──┘ └────────────────────────┘
type      UUIDv7 (base32)
```

It combines the best properties of several identifier schemes:

- **Type-safe** — the prefix says what the id refers to, so a `user_…` can never
  be mistaken for an `order_…`. Mixing them up becomes obvious in logs, URLs and
  code review instead of silently pointing at the wrong row.
- **K-sortable / time-ordered** — the underlying UUIDv7 embeds a millisecond
  timestamp in its most significant bits, so ids sort roughly by creation time.
  Stored the right way (see [Storage & indexing](#storage--indexing)), this gives
  good B-tree locality on insert, unlike random UUIDv4/`NEWID()`.
- **Compact & URL-safe** — 26 base32 characters instead of 36 hyphenated hex,
  using a lowercase, unambiguous alphabet (no `i`, `l`, `o`, `u`).
- **Interoperable** — the generated ids are RFC 9562 conformant and round-trip
  with the reference TypeId libraries (Go, Rust, TypeScript, Python, …), so a
  value minted in SQL Server decodes identically elsewhere.
- **Globally unique** — 74 cryptographically random bits per id, from
  `CRYPT_GEN_RANDOM`.

Everything is installed into a dedicated `typeid` schema and exposed as a small
set of scalar functions, the most important being `typeid.New('prefix')`, which
is safe to drop straight into a column `DEFAULT`.

## Requirements

- **SQL Server 2025**, with the target database at **compatibility level 170**.

The implementation relies on features that arrived across recent versions:

| Feature | Used for | Introduced |
| --- | --- | --- |
| `REGEXP_LIKE` | prefix / suffix validation | SQL Server 2025 (compat 170) |
| `GET_BIT`, `SET_BIT`, `RIGHT_SHIFT` | base32 bit manipulation on `binary(16)` | SQL Server 2022 (compat 160) |
| `CRYPT_GEN_RANDOM` | cryptographically secure random bits | long-standing |
| `DATEDIFF_BIG` | 48-bit Unix-millisecond timestamps | SQL Server 2016 |

> SQL Server has **no native UUIDv7 generator** — `NEWID()` is UUIDv4 and
> `NEWSEQUENTIALID()` is a different, non-portable scheme — so the v7 layout is
> built by hand here.

## Install / Uninstall

Run [`dist/typeid-install.sql`](dist/typeid-install.sql) on your database. To
remove everything, run [`dist/typeid-uninstall.sql`](dist/typeid-uninstall.sql)
(it drops every object and the schema). Both are self-contained and safe to
copy/paste into a project.

Regenerate them from the individual sources under `sql/` with `./build.sh`.

## Usage

```sql
CREATE TABLE MyTable (
    Id    varchar(90)  NOT NULL DEFAULT typeid.New('user'),
    Label varchar(100),
    CONSTRAINT PK_MyTable  PRIMARY KEY (Id),
    CONSTRAINT CK_MyTable_Id CHECK (typeid.IsValid(Id) = 1)
);
GO

INSERT INTO MyTable (Label) VALUES ('new label');
GO

SELECT Id,
       typeid.Decode(Id)       AS Uuid,
       typeid.GetTimestamp(Id) AS CreatedUtc
FROM MyTable;
GO
```

| Id                              | Uuid                                 | CreatedUtc                  |
| ------------------------------- | ------------------------------------ | --------------------------- |
| user_01h455vb4pex5vsknk084sn02q | 01890a5d-ac96-774b-bcce-b302099a8057 | 2023-06-30 03:34:18.5180000 |

## API

All objects live in the `typeid` schema.

| Function | Returns | Description |
| --- | --- | --- |
| `typeid.New(@prefix)` | `varchar(90)` | Generate a new TypeId. Safe as a column `DEFAULT`. |
| `typeid.Encode(@prefix, @uuid)` | `varchar(90)` | Build a TypeId from a prefix and a canonical UUID string. |
| `typeid.Decode(@typeid)` | `char(36)` | The canonical, lowercase, hyphenated UUID of a TypeId. |
| `typeid.GetPrefix(@typeid)` | `varchar(63)` | The prefix (`''` when there is none). |
| `typeid.GetTimestamp(@typeid)` | `datetime2` | The embedded UUIDv7 timestamp, in **UTC**. |
| `typeid.IsValid(@typeid)` | `bit` | Whether a value is a well-formed TypeId. |

`typeid.NewUuidV7`, `typeid.Encode/DecodeBase32`, `typeid.RandomSource` and the
`typeid.IsValid{Prefix,Suffix}` helpers are also installed; they are building
blocks and normally not called directly.

### Validity rules (per the TypeId spec)

- **Prefix**: 0–63 characters of lowercase ASCII `[a-z]` and underscores, and may
  neither start nor end with an underscore. An empty prefix is allowed and is
  written as the bare 26-char suffix, with **no** leading underscore.
- **Suffix**: exactly 26 characters of the lowercase Crockford base32 alphabet
  (`0123456789abcdefghjkmnpqrstvwxyz`). The leading character must be `0`–`7`,
  because 26 × 5 = 130 bits encode a 128-bit value, so the top two bits are zero.

## How it works

- The 16 UUID bytes are assembled and manipulated as `binary(16)`, using the
  native bit functions — there is no string-of-`'0'`/`'1'` arithmetic.
- `typeid.NewUuidV7` lays out the bytes per RFC 9562 §5.7: `bytes[0..5]` are the
  big-endian `unix_ts_ms`, the high nibble of `bytes[6]` is the version (`7`),
  and the top two bits of `bytes[8]` are the variant (`10`); the remaining 74
  bits come from `CRYPT_GEN_RANDOM`.
- Base32 encode/decode walk the 130-bit view five bits at a time with
  `GET_BIT` / `SET_BIT`.
- Validation is done with `REGEXP_LIKE`; decoding additionally rejects any
  out-of-alphabet character and any suffix whose leading character is above `7`.
- There is **no dynamic SQL** anywhere (no `EXEC` / `sp_executesql`, no
  string concatenation into an executed statement), so there is no SQL-injection
  surface — inputs only ever flow into returned string values.

## Design decisions & caveats

### Errors are returned as `NULL`

T-SQL scalar functions cannot `THROW` or `RAISERROR`. Since `typeid.New` must
stay a scalar function to be usable as a column `DEFAULT`, invalid input yields
`NULL` rather than raising. Enforce validity at write time with a
`CHECK (typeid.IsValid(Id) = 1)` constraint, as in the usage example. `Encode`,
`Decode`, `IsValid`, `GetPrefix` and `GetTimestamp` are deterministic and safe
to use inside computed columns and constraints.

### Ordering is millisecond-granular, not strictly monotonic

The random bits come from `CRYPT_GEN_RANDOM` (a CSPRNG). T-SQL cannot read a
sub-millisecond clock, so two ids created within the **same millisecond** are
ordered only by their random tail, not strictly monotonically. They remain
millisecond-K-sortable, which is enough for index locality; if you need a strict
per-millisecond sequence, combine generation with a
[`SEQUENCE`](https://learn.microsoft.com/sql/t-sql/statements/create-sequence-transact-sql).

### Storage & indexing

Store TypeIds (or the decoded UUID) in a form that **preserves byte order** so
the embedded timestamp keeps sorting first:

- **`varchar(90)`** — store the TypeId as-is. Recommended default: the base32
  text sorts time-first, it is what you read and log, and it is copy/paste-able.
- **`binary(16)`** — store the raw UUID via
  `CONVERT(binary(16), REPLACE(typeid.Decode(Id), '-', ''), 2)`. Sorts
  big-endian, i.e. time-ordered — good for a narrow clustered key.
- **Avoid `uniqueidentifier`.** SQL Server sorts and stores `uniqueidentifier`
  with a *mixed-endian* byte order, which scrambles the leading timestamp: a
  UUIDv7 stored as `uniqueidentifier` inserts almost as randomly as a UUIDv4,
  reintroducing page splits and fragmentation. For the same reason this library
  never round-trips values through `uniqueidentifier`; `typeid.Decode` returns a
  `char(36)` string in canonical byte order.

### Case sensitivity

The canonical form is lowercase. Decoding is case-sensitive (a binary collation
is used internally), so non-canonical uppercase input is rejected rather than
silently accepted — independent of the database's default collation.

### Length handling

Public functions that take a whole TypeId accept a type wider than the 90-char
maximum, so an over-long value is rejected by the length rules instead of being
silently truncated to a length that could pass validation.

## Tests

[`sql/tests/roundtrip.sql`](sql/tests/roundtrip.sql) is an assertion batch that
`THROW`s on any mismatch. It covers the official spec vectors (encode/decode both
ways), timestamp extraction, generator conformance (version/variant nibbles), and
rejection of malformed input. Run it after installing; it prints
`All TypeId tests passed.` on success.

## Contributing

Contributions are welcome. A few things to know before you start:

- **Sources live under `sql/`.** They are organized so that folder/name order
  encodes the dependency order:
  - [`sql/00-schema/`](sql/00-schema/) — the `typeid` schema.
  - [`sql/10-internal/`](sql/10-internal/) — building blocks (random source,
    UUIDv7 layout, base32 encode/decode).
  - [`sql/20-public/`](sql/20-public/) — the public API (`New`, `Encode`,
    `Decode`, `IsValid`, …).
  - [`sql/tests/`](sql/tests/) — the assertion batch.
- **Never edit `dist/*.sql` by hand.** Those files are generated (they carry a
  `-- Generated by build.sh -- do not edit by hand.` header). Edit the sources
  under `sql/`, then regenerate the install/uninstall scripts with
  [`./build.sh`](build.sh).
- **Run the tests.** After (re)installing on a SQL Server 2025 database, execute
  [`sql/tests/roundtrip.sql`](sql/tests/roundtrip.sql); it must print
  `All TypeId tests passed.`.
- **Pull requests.** Fork → create a branch → make your change under `sql/` →
  run `./build.sh` and the tests until green → open a PR describing the change.

Please keep the "no dynamic SQL / no `uniqueidentifier` round-trip" invariants
described in [How it works](#how-it-works) and
[Design decisions & caveats](#design-decisions--caveats).

## Credits

This project stands on the shoulders of prior work:

- The [**TypeId** specification](https://github.com/jetify-com/typeid) by
  [Jetify](https://www.jetify.com/) (MIT licensed) — the format this library
  implements and round-trips with.
- [**UUIDv7 — RFC 9562**](https://www.rfc-editor.org/rfc/rfc9562) — the
  underlying time-ordered UUID layout.
- **Crockford base32** by Douglas Crockford — the compact, unambiguous alphabet
  used for the suffix.

## License

Released under the **MIT License** — see [LICENSE](LICENSE).

This project is an independent implementation of the TypeId specification, which
is itself MIT licensed; the two licenses are compatible.
