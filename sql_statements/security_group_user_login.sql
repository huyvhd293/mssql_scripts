-- Retrieve all login
SELECT s.name as login,
       s.type_desc as login_type,
       l.password_hash,
       s.create_date,
       s.modify_date,
       CASE WHEN s.is_disabled = 1 THEN 'Disabled'
            ELSE 'Enabled' END AS status
FROM sys.server_principals s
LEFT JOIN sys.sql_logins l 
on (s.principal_id = l.principal_id)
-- C = CERTIFICATE_MAPPED_LOGIN
-- R = SERVER_ROLE
WHERE s.type NOT IN ('C', 'R')
ORDER BY s.name;

-- List database permission for each user
SELECT
    perms.state_desc AS State,
    permission_name AS [Permission],
    obj.name AS [on Object],
    dp.name AS [to User Name]
FROM sys.database_permissions AS perms
JOIN sys.database_principals AS dp
    ON perms.grantee_principal_id = dp.principal_id
JOIN sys.objects AS obj
    ON perms.major_id = obj.object_id;

-- List server-role members
SELECT roles.principal_id AS RolePrincipalID,
    roles.name AS RolePrincipalName,
    server_role_members.member_principal_id AS MemberPrincipalID,
    members.name AS MemberPrincipalName
FROM sys.server_role_members AS server_role_members
INNER JOIN sys.server_principals AS roles
    ON server_role_members.role_principal_id = roles.principal_id
LEFT JOIN sys.server_principals AS members
    ON server_role_members.member_principal_id = members.principal_id;


-- List all database principals
SELECT dRole.name AS [Database Role Name], dp.name AS [Members]
FROM sys.database_role_members AS dRo
JOIN sys.database_principals AS dp
    ON dRo.member_principal_id = dp.principal_id
JOIN sys.database_principals AS dRole
    ON dRo.role_principal_id = dRole.principal_id;