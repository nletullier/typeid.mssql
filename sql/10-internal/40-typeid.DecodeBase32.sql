-- Internal helper: decode a 26-character Crockford base32 suffix back to the
-- 128-bit UUID (binary(16)). Inverse of typeid.EncodeBase32.
--
-- Returns NULL when the input is malformed:
--   * any character outside the (lowercase, case-sensitive) Crockford alphabet;
--   * a leading character above '7', which would require more than 128 bits
--     (26 * 5 = 130 bits, so the top two bits must be zero).
CREATE OR ALTER FUNCTION typeid.DecodeBase32(@suffix char(26))
RETURNS binary(16)
AS
BEGIN
    IF @suffix IS NULL OR LEN(@suffix) <> 26
        RETURN NULL;

    DECLARE @alphabet char(32) = '0123456789abcdefghjkmnpqrstvwxyz';
    DECLARE @out binary(16) = 0x00000000000000000000000000000000;

    DECLARE @i int = 0;
    WHILE @i < 26
    BEGIN
        DECLARE @char char(1) = SUBSTRING(@suffix, @i + 1, 1);
        -- BIN2 collation: canonical (lowercase) alphabet only; reject anything else.
        DECLARE @val int = CHARINDEX(@char, @alphabet COLLATE Latin1_General_BIN2) - 1;

        IF @val < 0
            RETURN NULL;                        -- character not in the alphabet
        IF @i = 0 AND @val > 7
            RETURN NULL;                        -- overflows 128 bits

        DECLARE @msb int = 129 - 5 * @i;
        DECLARE @k int = 0;
        WHILE @k < 5
        BEGIN
            DECLARE @pos int = @msb - @k;
            IF @pos <= 127
            BEGIN
                DECLARE @bit int = RIGHT_SHIFT(@val, 4 - @k) & 1;
                SET @out = SET_BIT(@out, @pos, @bit);
            END
            SET @k += 1;
        END

        SET @i += 1;
    END

    RETURN @out;
END
GO
