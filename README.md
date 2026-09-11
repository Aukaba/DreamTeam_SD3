# DreamTeam_SD3

Welcome to the DreamTeam_SD3 project! This is a Flutter application backed by PostgreSQL and Supabase. 

## 🚀 Onboarding & Initialization

Follow these steps to get your local development environment set up.

### 1. Prerequisites
Ensure you have the following installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Ensure `flutter` is in your `PATH`)
- [Git](https://git-scm.com/)

### 2. Project Setup
Clone the repository and install the Flutter dependencies.

```bash
git clone https://github.com/your-username/DreamTeam_SD3.git
cd DreamTeam_SD3

# (If the project scaffolding hasn't been generated yet, you might need to run: flutter create .)

# Install Flutter dependencies
flutter pub get
```

### 3. Environment Variables
This project uses `.env` files to securely manage credentials. **Never commit your `.env` file to version control.**

1. Copy the `.env.example` file to create your local `.env` file:
   ```bash
   cp .env.example .env
   ```
2. Open the `.env` file and fill in the actual credentials for your database and Supabase instance.
3. Ensure that your `pubspec.yaml` declares the `.env` file under the `assets` block:
   ```yaml
   flutter:
     assets:
       - .env
   ```

### 4. Database Migrations
We use [dbmate](https://github.com/amacneil/dbmate) for file-based SQL migrations. 

1. **Get dbmate**: If you are on Windows, download `dbmate-windows-amd64.exe` from the [dbmate GitHub releases](https://github.com/amacneil/dbmate/releases) and rename it to `dbmate.exe` in the root folder. If you are on macOS/Linux, install it via Homebrew (`brew install dbmate`) or your preferred package manager.
2. Ensure your `.env` has the correct `DATABASE_URL`.
3. Apply the migrations to set up your local database schema:
   ```bash
   ./dbmate.exe up    # On Windows
   # OR
   dbmate up          # On macOS/Linux
   ```

> **Note**: For a full list of database commands (like creating new migrations or rolling back), please refer to the [MIGRATIONS_GUIDE.md](./MIGRATIONS_GUIDE.md).

### 5. Run the App
Once everything is configured, you can launch the app:

```bash
flutter run
```