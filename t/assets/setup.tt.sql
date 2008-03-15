CREATE DATABASE [% connection.database %] WITH TEMPLATE template0;
--
CREATE USER [% connection.username %] WITH PASSWORD '[% connection.password %]';
