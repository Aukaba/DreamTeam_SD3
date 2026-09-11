# Database Migrations Guide

This project uses [dbmate](https://github.com/amacneil/dbmate) as the file-based database migration system. It is language-agnostic and relies purely on `.sql` files, making it perfect for our stack.
A standalone Windows binary (`dbmate.exe`) has been downloaded to the project root for your convenience.

## Configuration
The migration environment depends on the `DATABASE_URL` inside your `.env` file. 

Example `.env`:
```env
DATABASE_URL="postgres://username:password@127.0.0.0:5432/database_name?sslmode=disable"
```

## Migration Commands

Here are the exact commands you need to manage the database schema:

### 1. Generate a New Migration
To create a new, timestamped migration file in the `db/migrations` directory, run:
```bash
./dbmate.exe new <migration_name>
```
*Example: `./dbmate.exe new create_users_table`*

### 2. Apply Migrations (Migrate Up)
To run all pending migrations against the database, use:
```bash
./dbmate.exe up
```
*Note: dbmate will automatically create the database if it doesn't exist.*

### 3. Rollback Migrations (Migrate Down)
To undo the most recently applied migration, use:
```bash
./dbmate.exe down
```

### 4. Check Migration Status
To see which migrations have been applied and which are pending:
```bash
./dbmate.exe status
```

### 5. Dump Schema
To update the `db/schema.sql` file representing the current database state:
```bash
./dbmate.exe dump
```
*This happens automatically when you run `./dbmate.exe up` or `./dbmate.exe down`.*
