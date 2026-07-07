-- Returns 1 when @prefix is a valid TypeId prefix, else 0.
--
-- Per the TypeId spec, a prefix is 0-63 characters of lowercase ASCII [a-z]
-- and underscores, and may neither start nor end with an underscore. The empty
-- prefix is valid; NULL is not.
-- @prefix is intentionally wider than 63 so an over-long value is not silently
-- truncated to 63 by the parameter type before the regex length check runs.
CREATE OR ALTER FUNCTION typeid.IsValidPrefix(@prefix varchar(90))
RETURNS bit
AS
BEGIN
    IF @prefix IS NULL
        RETURN 0;
    IF @prefix = ''
        RETURN 1;
    IF REGEXP_LIKE(@prefix, '^[a-z]([a-z_]{0,61}[a-z])?$')
        RETURN 1;
    RETURN 0;
END
GO
