-- Decodes a TypeId to its canonical lowercase hyphenated UUID string.
-- Returns NULL when @typeid is not a well-formed TypeId.
-- @typeid is wider than 90 so an over-long value is rejected by typeid.IsValid
-- rather than truncated to a length that might pass.
CREATE OR ALTER FUNCTION typeid.Decode(@typeid varchar(255))
RETURNS char(36)
AS
BEGIN
    IF typeid.IsValid(@typeid) = 0
        RETURN NULL;

    DECLARE @bytes binary(16) = typeid.DecodeBase32(RIGHT(@typeid, 26));
    IF @bytes IS NULL
        RETURN NULL;

    DECLARE @hex char(32) = LOWER(CONVERT(char(32), @bytes, 2));
    RETURN LEFT(@hex, 8) + '-'
         + SUBSTRING(@hex, 9, 4) + '-'
         + SUBSTRING(@hex, 13, 4) + '-'
         + SUBSTRING(@hex, 17, 4) + '-'
         + SUBSTRING(@hex, 21, 12);
END
GO
