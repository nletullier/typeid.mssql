-- Extracts the embedded UUIDv7 timestamp from a TypeId as a UTC datetime2.
-- Returns NULL when @typeid is not well-formed.
--
-- The first 48 bits of the UUID are unix_ts_ms (big-endian milliseconds since
-- the Unix epoch). The value is added to the epoch as whole days plus the
-- remaining milliseconds so that both DATEADD arguments stay within int range
-- across the full 48-bit timestamp span.
-- @typeid is wider than 90 so an over-long value is rejected by typeid.IsValid
-- rather than truncated to a length that might pass.
CREATE OR ALTER FUNCTION typeid.GetTimestamp(@typeid varchar(255))
RETURNS datetime2
AS
BEGIN
    IF typeid.IsValid(@typeid) = 0
        RETURN NULL;

    DECLARE @bytes binary(16) = typeid.DecodeBase32(RIGHT(@typeid, 26));
    IF @bytes IS NULL
        RETURN NULL;

    -- 48-bit big-endian milliseconds, widened to bigint via two leading zero bytes.
    DECLARE @ms bigint = CONVERT(bigint, 0x0000 + SUBSTRING(@bytes, 1, 6));

    DECLARE @epoch datetime2 = '1970-01-01T00:00:00';
    RETURN DATEADD(MILLISECOND, @ms % 86400000, DATEADD(DAY, @ms / 86400000, @epoch));
END
GO
