-- Returns 1 when @typeid is a well-formed TypeId, else 0.
--
-- The prefix and suffix are split on the LAST underscore. A value with no
-- underscore is treated as an empty-prefix TypeId (bare suffix). A leading
-- underscore is invalid: an empty prefix must be written without a separator.
--
-- @typeid is wider than the 90-char maximum of a valid TypeId so an over-long
-- value stays over-long (and is rejected) instead of being silently truncated
-- to a length that could pass validation.
CREATE OR ALTER FUNCTION typeid.IsValid(@typeid varchar(255))
RETURNS bit
AS
BEGIN
    IF @typeid IS NULL
        RETURN 0;

    DECLARE @revPos int = CHARINDEX('_', REVERSE(@typeid));
    DECLARE @prefix varchar(255);
    DECLARE @suffix varchar(255);

    IF @revPos = 0
    BEGIN
        SET @prefix = '';
        SET @suffix = @typeid;
    END
    ELSE
    BEGIN
        DECLARE @lastPos int = LEN(@typeid) - @revPos + 1;   -- index of the last '_'
        SET @prefix = LEFT(@typeid, @lastPos - 1);
        SET @suffix = SUBSTRING(@typeid, @lastPos + 1, LEN(@typeid));
        IF @prefix = ''
            RETURN 0;   -- leading underscore / empty prefix with separator
    END

    IF typeid.IsValidPrefix(@prefix) = 1 AND typeid.IsValidSuffix(@suffix) = 1
        RETURN 1;
    RETURN 0;
END
GO
