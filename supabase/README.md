# Sakhi Bachat Gat Management Application - Supabase Setup Guide

This folder contains the complete, production-ready database schema, storage policies, triggers, functions, and seed data for **Sakhi Bachat Gat (महिला बचत गट व्यवस्थापन ॲप)**.

---

## 📁 File Structure

1. **`schema.sql`**
   - **PostgreSQL Extensions**: `uuid-ossp`, `pgcrypto`
   - **Custom Enums**: `user_role_type`, `record_status_type`, `savings_category_type`, `loan_status_type`, `emi_status_type`, `payment_mode_type`, etc.
   - **32 Normalized Tables**: Groups, Profiles, User Permissions, Members, Savings, Loans, Loan EMIs, Meetings, Meeting Attendance, Resolutions, Votes, Incomes, Expenses, Bank Accounts, Bank Transactions, Cash Book, Bank Reconciliations, Products, Suppliers, Stock Transactions, Customers, Sales, Sale Items, Member Businesses, Contributions, Fines, Government Schemes, Applications, Documents, Trainings, Events, Dues, Notifications, Audit Logs, Settings.
   - **Automated Triggers**:
     - Auto `updated_at` timestamps on all tables.
     - Auto stock deduction/addition on inventory transactions and sales.
     - Auto bank balance updates on deposits and withdrawals.
     - Auto loan balance settlement when EMI is marked as paid.
   - **Row Level Security (RLS)**:
     - Strict multi-tenant isolation by `group_id`.
     - Granular module & action permissions (`can_view`, `can_add`, `can_edit`, `can_delete`, `can_approve`, `can_print`, `can_export`).
     - Admin overrides and profile access rules.
   - **Dashboard RPC Function**:
     - `get_dashboard_metrics(p_group_id UUID)`: Real-time calculation of total members, savings, active loans, pending EMIs, bank balance, cash in hand, income, expenses, sales, and net profit.
   - **Audit Trail RPC Function**:
     - `log_audit_event(...)` for logging critical operations.

2. **`storage_setup.sql`**
   - **Supabase Storage Buckets**:
     - `member-photos` (Public read, authenticated group upload)
     - `member-documents` (Private, tenant-isolated)
     - `group-assets` (Logos, certificates)
     - `receipts-invoices` (Private PDF receipts and invoices)
     - `expense-attachments` (Private bill/receipt scans)
   - **Storage RLS Policies**: Group folder isolation `group_id/...`.

3. **`seed_sample_data.sql`**
   - Realistic test data matching the UI poster:
     - **Group**: Sakhi Mahila Bachat Gat, Sangola (Registration: MAH-MH-1234)
     - **Members**: Sunita Pawar (President), Meena Jadhav (Secretary), Lata More, Kavita Shinde (Treasurer), Asha Patil
     - **Products**: Papad, Pickle, Masala, Handicraft, Clothes
     - **Bank Account**: State Bank of India, Sangola Branch (Balance: ₹2,50,000)
     - **Cash in Hand**: ₹35,000
     - **Savings**: ₹1,25,000 pool
     - **Active Loans**: ₹75,000 (L001 Sunita Pawar, L002 Meena Jadhav) with EMI schedule
     - **Dues**: ₹8,700 pending dues
     - **Scheduled Meetings & Notifications**: Ready for instant dashboard preview.

---

## 🚀 How to Apply to Your Supabase Project

1. **Login to Supabase**:
   - Go to [https://supabase.com](https://supabase.com) and open your project dashboard.

2. **Open SQL Editor**:
   - Click on the **SQL Editor** tab from the left sidebar.

3. **Execute `schema.sql`**:
   - Copy the entire contents of `supabase/schema.sql` into a new query.
   - Click **Run**. All tables, types, triggers, and RLS policies will be created.

4. **Execute `storage_setup.sql`**:
   - Copy the contents of `supabase/storage_setup.sql`.
   - Click **Run** to set up buckets and storage permissions.

5. **Execute `seed_sample_data.sql` (Optional for instant testing)**:
   - Run `supabase/seed_sample_data.sql` to populate sample group, members, loans, products, and metrics matching the UI mockups.

---

## 🔑 Authentication & Admin Setup

When a new Main Admin signs up in your Flutter app using Supabase Auth (Email or Mobile OTP):
1. A new user is created in `auth.users`.
2. Insert a row into `public.groups` with the Bachat Gat details.
3. Insert a profile into `public.profiles` with `id = auth.users.id`, `group_id = groups.id`, `role = 'admin'`, `is_main_admin = true`.
4. The admin can now create sub-users (President, Secretary, Treasurer, Employee) and configure their individual permissions via the User Management screen.
