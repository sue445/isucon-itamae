CREATE USER IF NOT EXISTS 'isucon'@'%' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON *.* TO 'isucon'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;