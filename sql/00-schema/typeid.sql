-- Schema hosting all TypeId objects.
IF SCHEMA_ID(N'typeid') IS NULL
    EXEC (N'CREATE SCHEMA typeid');
GO
