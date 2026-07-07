-- Generates a brand-new TypeId for the given prefix, e.g. typeid.New('user').
--
-- This is the primary entry point and is safe to use as a column DEFAULT:
--   Id varchar(90) NOT NULL DEFAULT typeid.New('user')
--
-- Returns NULL when the prefix is invalid (see typeid.IsValidPrefix). Pair it
-- with a CHECK (typeid.IsValid(Id) = 1) constraint to reject bad values at
-- write time, since scalar functions cannot raise errors themselves.
CREATE OR ALTER FUNCTION typeid.New(@prefix varchar(90))
RETURNS varchar(90)
AS
BEGIN
    RETURN typeid.Encode(@prefix, typeid.NewUuidV7());
END
GO
