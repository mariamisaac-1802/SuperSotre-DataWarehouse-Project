/*
===============================================================================
Create Database and Schemas
===============================================================================
Script Purpose:
    This script creates a new database named 'SuperstoreDW' after checking if
    it already exists. If the database exists, it is dropped and recreated.
    The script also creates four schemas: 'staging', 'bronze', 'silver', 'gold'.

WARNING:
    Running this script will drop the entire 'SuperstoreDW' database if it
    already exists. All data will be permanently deleted. Proceed with caution
    and ensure you have proper backups before running this script.
===============================================================================
*/

USE master;
GO

-- Drop and recreate the 'SuperstoreDW' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'SuperstoreDW')
BEGIN
    ALTER DATABASE SuperstoreDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SuperstoreDW;
END;
GO

CREATE DATABASE SuperstoreDW;
GO

USE SuperstoreDW;
GO

-- Create Schemas
CREATE SCHEMA staging;
GO

CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
