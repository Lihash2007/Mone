# Money OS - Agent Implementation Log

This document serves as a persistent state file for future agents to understand the core mechanics, recent updates, and how features are implemented in this repository.

## Core Architecture
- **Framework**: Flutter (Frontend), SQLite (Local Database)
- **Primary File**: `frontend/lib/main.dart` is a monolithic file containing the database schema initialization (`_initDatabase`), background processes (`onBackgroundMessage`), and all UI screens (`_screens`).
- **Core Plugins**:
  - `telephony`: For listening to incoming SMS and reading inbox.
  - `sqflite`: For all data persistence.
  - `home_widget`: For Android home screen widgets.

## Recent Features & Modifications

### 1. Multi-Account Tracking & SMS Filtering
- **Schema Updates**: Added an `accounts` table (`id`, `name`, `account_number`, `balance`, `type`). Appended `account_id` to the `transactions` table.
- **SMS Processing**: 
  - `onBackgroundMessage` (the background SMS listener) now queries the `accounts` table.
  - It matches incoming SMS text against user-defined `account_number`s. 
  - If a match is found, the transaction is assigned to that specific `account_id` and the account's `balance` is updated incrementally.
  - This prevents fake "credited/debited" messages from polluting the ledger.
- **Startup Sync**: On app launch (`_setupSmsListener`), the app automatically fetches the latest 50 SMS messages from the device inbox to ensure no offline transactions are missed.

### 2. Dashboard UI Updates
- Replaced the hardcoded "Total Available Balance" and "Monthly Budget" cards with dynamic account cards.
- The UI loops over the `accounts` table and renders a card for each (both `CASH` and `BANK`).
- **Dynamic Colors**: Cards render **Green** for positive balances and **Red** for negative balances (`bal < 0`).

### 3. Manage Accounts Modal
- Added a `_showManageAccountsModal` triggered from the `ProfileScreen` (under "System Setup" -> "Manage Accounts").
- Allows users to create new Bank or Cash accounts, specifying an account name and a tracking number (e.g., last 4 digits of a bank account).
- Users can delete accounts from this view as well.
- Input controllers are properly cleared, and local state (`setModalState` / `setState`) is triggered after database inserts to reflect real-time UI updates.

### 4. Manual Transaction Entry
- The `_showAddTransactionModal` was updated to include an Account Dropdown.
- When saving a manual transaction, it now updates the selected account's balance in real-time.

## Notes for Future Agents
- When adding new DB tables, ensure you update the schema inside `_initDatabase` in `main.dart`. If migrating existing users, use `ALTER TABLE` inside a `try-catch` block.
- For UI modals that use `FutureBuilder` (like the Manage Accounts or Categories modals), make sure you manage the text controllers outside of the `FutureBuilder` scope so they don't get overwritten on rebuilds. Clear them manually upon a successful DB insert.
- The Android app requires `flutter run` for deployment, and the backend logic heavily relies on native Android permissions for reading SMS.

*(Last Updated: October 2026)*

### 5. Transfer System & Total Balance Tracking
- **Total Balance Dashboard Card**: Added a new primary card at the front of the dashboard stack that dynamically calculates the sum of all accounts.
- **Account Disabling**: Added include_in_total (INTEGER DEFAULT 1) column to the ccounts table. Users can now toggle a Switch in the Manage Accounts modal to exclude specific accounts from the 'Total Balance' calculation.
- **Bank to Cash Transfers**: Added a 'Transfer' tab in the manual transaction entry modal. When selected, the user can deduct funds directly from a specified account without categorizing it as an expense, allowing for ATM withdrawal tracking.

### 6. Branding Update
- **App Name**: Renamed the Android app label to 'mone'.
- **Logo**: Updated the launcher icon across Android assets using the Glossy Green Finance M Emblem via flutter_launcher_icons.

### 7. Ledger Math Accuracy & Bank Name Metadata
- **Dynamic Math Fix**: Moved away from storing static balances that can go out-of-sync upon transaction edits. Balances are now 100% dynamically computed on the fly using initial_balance + SUM(income) - SUM(expense) from the ledger.
- **Account Metadata**: Added ank_name and initial_balance to the ccounts schema and updated the 'Manage Accounts' modal to support them. Dashboard cards now dynamically render the Bank Name alongside the Account Name.

### 8. Manual SMS Sync and Backend Consistency
- **Manual SMS Sync**: Added a 'Sync SMS Now' button to the Profile Settings screen. It requests permissions, scans the inbox, and imports missed messages ONLY if they match an existing bank ccount_number, ensuring no fake messages are logged.
- **Backend Schema Sync**: Mirrored the ank_name and initial_balance columns over to the FastAPI backend API via Alembic migrations so both databases are perfectly consistent.

### 9. Transfer System Overhaul
- **Double Entry Logic**: 'Transfer' type transactions in the Quick Add modal no longer just deduct from the bank. They now accurately create an EXPENSE (Transfer Out) from the source account and a matching INCOME (Transfer In) to the destination account.
- **To Account Dropdown**: Added a second account dropdown that dynamically appears when 'TRANSFER' is selected, allowing the user to select the destination account (e.g. CASH).
