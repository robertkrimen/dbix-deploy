CREATE DATABASE [% user.database %] WITH TEMPLATE template0;
--
CREATE USER [% user.username %] WITH PASSWORD '[% user.password %]';
