-- Internal helper: generate a fresh RFC 9562 UUIDv7 as a canonical
-- lowercase hyphenated string (char(36)).
--
-- Layout (128 bits), per RFC 9562 section 5.7:
--   bytes 0-5  : unix_ts_ms   (48-bit big-endian milliseconds since Unix epoch, UTC)
--   byte  6    : version (0111 = 7) in the high nibble, rand_a high bits in the low nibble
--   byte  7    : rand_a low bits
--   byte  8    : variant (10) in the top two bits, rand_b high bits below
--   bytes 9-15 : rand_b
--
-- The value is assembled in binary(16) and formatted directly from the raw
-- bytes. It is deliberately NOT round-tripped through uniqueidentifier, whose
-- mixed-endian storage would reorder the first three groups.
CREATE OR ALTER FUNCTION typeid.NewUuidV7()
RETURNS char(36)
AS
BEGIN
    DECLARE @unixMs bigint;
    DECLARE @rand binary(10);

    SELECT @unixMs = UnixMs, @rand = RandomBytes
    FROM typeid.RandomSource;

    -- Low 48 bits of the millisecond timestamp, big-endian.
    DECLARE @ts binary(6) = SUBSTRING(CONVERT(binary(8), @unixMs), 3, 6);

    -- Force version (7) and variant (10xx) bits, keeping the rest random.
    -- Go through tinyint so the int -> binary(1) narrowing is unambiguous.
    DECLARE @versionByte binary(1) =
        CONVERT(binary(1), CONVERT(tinyint, (CONVERT(int, SUBSTRING(@rand, 1, 1)) & 0x0F) | 0x70));
    DECLARE @variantByte binary(1) =
        CONVERT(binary(1), CONVERT(tinyint, (CONVERT(int, SUBSTRING(@rand, 3, 1)) & 0x3F) | 0x80));

    DECLARE @uuid binary(16) =
          @ts                       -- bytes 0-5
        + @versionByte              -- byte 6
        + SUBSTRING(@rand, 2, 1)    -- byte 7
        + @variantByte              -- byte 8
        + SUBSTRING(@rand, 4, 7);   -- bytes 9-15

    -- Raw hex (32 chars, no 0x prefix), lowercased, with canonical hyphens.
    DECLARE @hex char(32) = LOWER(CONVERT(char(32), @uuid, 2));

    RETURN LEFT(@hex, 8) + '-'
         + SUBSTRING(@hex, 9, 4) + '-'
         + SUBSTRING(@hex, 13, 4) + '-'
         + SUBSTRING(@hex, 17, 4) + '-'
         + SUBSTRING(@hex, 21, 12);
END
GO
