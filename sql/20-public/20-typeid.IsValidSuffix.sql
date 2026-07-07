-- Returns 1 when @suffix is a valid TypeId suffix, else 0.
--
-- A suffix is exactly 26 characters of the lowercase Crockford base32 alphabet
-- (0-9 and a-z excluding i, l, o, u). The leading character must be '0'-'7'
-- because 26 * 5 = 130 bits encode a 128-bit value, so the top two bits are
-- always zero.
-- @suffix is intentionally wider than 26 so an over-long value is not silently
-- truncated to 26 by the parameter type before the length check runs.
CREATE OR ALTER FUNCTION typeid.IsValidSuffix(@suffix varchar(90))
RETURNS bit
AS
BEGIN
    IF @suffix IS NULL
        RETURN 0;
    IF REGEXP_LIKE(@suffix, '^[0-7][0-9a-hjkmnp-tv-z]{25}$')
        RETURN 1;
    RETURN 0;
END
GO
