-- TypeId conformance tests. Run after installing the functions.
-- Prints one line per check and THROWs at the end if anything failed.
-- Requires database compatibility level 170 (REGEXP_LIKE).
SET NOCOUNT ON;

DECLARE @fail int = 0;

------------------------------------------------------------------------
-- Official spec vectors (https://github.com/jetify-com/typeid, valid.yml)
------------------------------------------------------------------------
DECLARE @vectors TABLE (
    name   varchar(40),
    prefix varchar(63),
    uuid   char(36),
    tid    varchar(90)
);
INSERT INTO @vectors (name, prefix, uuid, tid) VALUES
 ('nil',            '',       '00000000-0000-0000-0000-000000000000', '00000000000000000000000000'),
 ('one',            '',       '00000000-0000-0000-0000-000000000001', '00000000000000000000000001'),
 ('ten',            '',       '00000000-0000-0000-0000-00000000000a', '0000000000000000000000000a'),
 ('sixteen',        '',       '00000000-0000-0000-0000-000000000010', '0000000000000000000000000g'),
 ('thirty-two',     '',       '00000000-0000-0000-0000-000000000020', '00000000000000000000000010'),
 ('max-valid',      '',       'ffffffff-ffff-ffff-ffff-ffffffffffff', '7zzzzzzzzzzzzzzzzzzzzzzzzz'),
 ('valid-alphabet', 'prefix', '0110c853-1d09-52d8-d73e-1194e95b5f19', 'prefix_0123456789abcdefghjkmnpqrs'),
 ('valid-uuidv7',   'prefix', '01890a5d-ac96-774b-bcce-b302099a8057', 'prefix_01h455vb4pex5vsknk084sn02q');

-- Encode: prefix + uuid -> tid
SELECT @fail = @fail + COUNT(*)
FROM @vectors
WHERE typeid.Encode(prefix, uuid) IS DISTINCT FROM tid;
IF EXISTS (SELECT 1 FROM @vectors WHERE typeid.Encode(prefix, uuid) IS DISTINCT FROM tid)
    SELECT 'FAIL Encode' AS check_name, name, uuid, tid AS expected, typeid.Encode(prefix, uuid) AS actual
    FROM @vectors WHERE typeid.Encode(prefix, uuid) IS DISTINCT FROM tid;

-- Decode: tid -> uuid
SELECT @fail = @fail + COUNT(*)
FROM @vectors
WHERE typeid.Decode(tid) IS DISTINCT FROM uuid;
IF EXISTS (SELECT 1 FROM @vectors WHERE typeid.Decode(tid) IS DISTINCT FROM uuid)
    SELECT 'FAIL Decode' AS check_name, name, tid, uuid AS expected, typeid.Decode(tid) AS actual
    FROM @vectors WHERE typeid.Decode(tid) IS DISTINCT FROM uuid;

-- GetPrefix
SELECT @fail = @fail + COUNT(*)
FROM @vectors
WHERE typeid.GetPrefix(tid) IS DISTINCT FROM prefix;

------------------------------------------------------------------------
-- Invalid inputs must be rejected (IsValid = 0)
------------------------------------------------------------------------
-- tid is wider than the 90-char max so over-long values are stored intact.
DECLARE @invalid TABLE (name varchar(40), tid varchar(255));
INSERT INTO @invalid (name, tid) VALUES
 ('uppercase-prefix', 'PREFIX_00000000000000000000000000'),
 ('leading-underscore','_00000000000000000000000000'),
 ('trailing-underscore-prefix','prefix__00000000000000000000000000'),
 ('suffix-has-i',    'prefix_0123456789abcdefghijkmnpqr'),
 ('suffix-overflow', '8zzzzzzzzzzzzzzzzzzzzzzzzz'),
 ('suffix-too-short','0000000000000000000000000'),
 ('suffix-too-long', '000000000000000000000000000'),
 -- 64-char prefix (max is 63): must not be silently truncated then accepted
 ('prefix-too-long', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_00000000000000000000000000'),
 -- 91 chars = a valid 90-char TypeId plus one trailing char: truncation to 90
 -- would wrongly accept it, so this guards the widened parameter types.
 ('overlong-truncates-to-valid', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_00000000000000000000000000z');

SELECT @fail = @fail + COUNT(*)
FROM @invalid
WHERE typeid.IsValid(tid) <> 0;
IF EXISTS (SELECT 1 FROM @invalid WHERE typeid.IsValid(tid) <> 0)
    SELECT 'FAIL should-be-invalid' AS check_name, name, tid FROM @invalid WHERE typeid.IsValid(tid) <> 0;

------------------------------------------------------------------------
-- GetTimestamp of the valid-uuidv7 vector (unix_ts_ms = 0x01890a5dac96)
------------------------------------------------------------------------
IF typeid.GetTimestamp('prefix_01h455vb4pex5vsknk084sn02q')
   <> CONVERT(datetime2, '2023-06-30T03:34:18.518')
BEGIN
    SET @fail += 1;
    SELECT 'FAIL GetTimestamp' AS check_name,
           typeid.GetTimestamp('prefix_01h455vb4pex5vsknk084sn02q') AS actual;
END

------------------------------------------------------------------------
-- Freshly generated ids are RFC 9562 UUIDv7 and valid TypeIds
------------------------------------------------------------------------
DECLARE @uuid char(36) = typeid.NewUuidV7();
IF SUBSTRING(@uuid, 15, 1) <> '7'
BEGIN SET @fail += 1; SELECT 'FAIL version-nibble' AS check_name, @uuid AS uuid; END
IF SUBSTRING(@uuid, 20, 1) NOT IN ('8','9','a','b')
BEGIN SET @fail += 1; SELECT 'FAIL variant-nibble' AS check_name, @uuid AS uuid; END

DECLARE @tid varchar(90) = typeid.New('user');
IF typeid.IsValid(@tid) <> 1 OR typeid.GetPrefix(@tid) <> 'user' OR LEN(@tid) <> 31
BEGIN SET @fail += 1; SELECT 'FAIL New(user)' AS check_name, @tid AS tid; END

-- Round-trip: Encode(Decode(x)) = x
IF typeid.Encode('user', typeid.Decode(@tid)) <> @tid
BEGIN SET @fail += 1; SELECT 'FAIL roundtrip-new' AS check_name, @tid AS tid; END

------------------------------------------------------------------------
IF @fail > 0
    THROW 50000, 'TypeId tests failed. See result grids above.', 1;
PRINT 'All TypeId tests passed.';
