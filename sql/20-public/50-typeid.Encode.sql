-- Builds a TypeId from a prefix and a canonical UUID string.
--
-- Returns NULL when the prefix is invalid (see typeid.IsValidPrefix) or the
-- UUID is not a 32-hex-digit value (with or without hyphens). Scalar functions
-- cannot raise errors, so invalid input yields NULL rather than throwing.
-- An empty prefix produces the bare 26-character suffix, with no separator.
-- @prefix is wider than 63 so an over-long prefix reaches typeid.IsValidPrefix
-- intact (and is rejected) instead of being silently truncated to 63.
CREATE OR ALTER FUNCTION typeid.Encode(@prefix varchar(90), @uuid char(36))
RETURNS varchar(90)
AS
BEGIN
    IF @uuid IS NULL OR typeid.IsValidPrefix(@prefix) = 0
        RETURN NULL;

    DECLARE @hex varchar(32) = REPLACE(@uuid, '-', '');
    IF NOT REGEXP_LIKE(@hex, '^[0-9a-fA-F]{32}$')
        RETURN NULL;

    DECLARE @suffix char(26) = typeid.EncodeBase32(CONVERT(binary(16), @hex, 2));

    IF @prefix = ''
        RETURN @suffix;
    RETURN @prefix + '_' + @suffix;
END
GO
