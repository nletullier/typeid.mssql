-- Internal helper: encode a 128-bit UUID (binary(16)) as the 26-character
-- Crockford base32 suffix used by TypeId.
--
-- The 128 bits are left-padded with two zero bits to reach 130 bits, then
-- split into 26 groups of 5 bits, most significant first. Bits are read with
-- GET_BIT, whose offset 0 is the least significant bit, so bit offset N of the
-- binary maps to "virtual" MSB-first position N; the two pad bits sit at virtual
-- positions 128-129 and always read as 0.
CREATE OR ALTER FUNCTION typeid.EncodeBase32(@bytes binary(16))
RETURNS char(26)
AS
BEGIN
    IF @bytes IS NULL
        RETURN NULL;

    DECLARE @alphabet char(32) = '0123456789abcdefghjkmnpqrstvwxyz';
    DECLARE @out varchar(26) = '';

    DECLARE @i int = 0;
    WHILE @i < 26
    BEGIN
        DECLARE @msb int = 129 - 5 * @i;   -- most significant bit of this group
        DECLARE @val int = 0;

        DECLARE @k int = 0;
        WHILE @k < 5
        BEGIN
            DECLARE @pos int = @msb - @k;
            DECLARE @bit int = CASE WHEN @pos <= 127 THEN GET_BIT(@bytes, @pos) ELSE 0 END;
            SET @val = @val * 2 + @bit;
            SET @k += 1;
        END

        SET @out = @out + SUBSTRING(@alphabet, @val + 1, 1);
        SET @i += 1;
    END

    RETURN @out;
END
GO
