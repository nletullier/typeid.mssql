-- Internal helper.
-- Scalar UDFs cannot call non-deterministic sources such as CRYPT_GEN_RANDOM
-- or SYSUTCDATETIME directly, so we surface them through a view that
-- typeid.NewUuidV7 selects from.
--
--   UnixMs      : current UTC time as milliseconds since the Unix epoch (fits 48 bits).
--   RandomBytes : 10 cryptographically secure random bytes (CSPRNG), enough to fill
--                 the 74 random bits of a UUIDv7 (rand_a 12 bits + rand_b 62 bits).
CREATE OR ALTER VIEW typeid.RandomSource
AS
SELECT
    DATEDIFF_BIG(MILLISECOND, '1970-01-01', SYSUTCDATETIME()) AS UnixMs,
    CRYPT_GEN_RANDOM(10) AS RandomBytes;
GO
