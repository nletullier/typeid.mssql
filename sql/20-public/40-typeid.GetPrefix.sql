-- Returns the prefix of a TypeId (the part before the last underscore),
-- or '' when there is no underscore (empty-prefix TypeId). NULL in, NULL out.
CREATE OR ALTER FUNCTION typeid.GetPrefix(@typeid varchar(255))
RETURNS varchar(63)
AS
BEGIN
    IF @typeid IS NULL
        RETURN NULL;

    DECLARE @revPos int = CHARINDEX('_', REVERSE(@typeid));
    IF @revPos = 0
        RETURN '';

    RETURN LEFT(@typeid, LEN(@typeid) - @revPos);
END
GO
