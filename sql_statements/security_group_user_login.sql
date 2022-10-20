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