-- ==============================================================================
-- PROJECT: Sakhi Bachat Gat Management Application
-- DESCRIPTION: Complete Supabase PostgreSQL Production Database Schema
-- COMPREHENSIVE: Multi-tenant Groups, Profiles & RBAC, Granular Permissions,
--               Members, Savings, Loans & EMI Schedule, Meetings, Resolutions & Voting,
--               Incomes, Expenses, Bank Accounts, Bank Transactions, Cash Book,
--               Bank Reconciliation, Products, Suppliers, Inventory / Stock Transactions,
--               Customers, Sales & Invoicing, Member Businesses, Contributions, Fines,
--               Government Schemes & Applications, Document Management, Trainings & Skills,
--               Events & Activities, Central Dues & Overdues, Real-time Notifications,
--               Audit Logs, and Group Application Settings.
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. ENUMS & DOMAIN TYPES
-- ==============================================================================

DO $$ BEGIN
    CREATE TYPE user_role_type AS ENUM ('admin', 'president', 'secretary', 'treasurer', 'employee');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE record_status_type AS ENUM ('active', 'inactive', 'suspended', 'closed', 'archived');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE savings_category_type AS ENUM ('monthly', 'weekly', 'special', 'festival', 'other');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE loan_status_type AS ENUM ('applied', 'under_review', 'approved', 'disbursed', 'closed', 'rejected', 'defaulted');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE emi_status_type AS ENUM ('pending', 'paid', 'partially_paid', 'overdue', 'waived');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_mode_type AS ENUM ('cash', 'bank_transfer', 'upi', 'cheque', 'neft_rtgs', 'credit', 'other');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE meeting_status_type AS ENUM ('scheduled', 'ongoing', 'completed', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE attendance_status_type AS ENUM ('present', 'absent', 'late', 'excused');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE stock_transaction_type AS ENUM ('stock_in', 'stock_out', 'adjustment', 'return', 'wastage');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE document_type_enum AS ENUM ('aadhaar', 'pan', 'bank_passbook', 'photo', 'loan_agreement', 'resolution', 'certificate', 'govt_document', 'other');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE verification_status_type AS ENUM ('pending', 'verified', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE due_status_type AS ENUM ('pending', 'partially_paid', 'paid', 'overdue', 'waived');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE notification_priority_type AS ENUM ('low', 'medium', 'high', 'urgent');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ==============================================================================
-- 3. GROUPS (MULTI-TENANT BACHAT GAT)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_name TEXT NOT NULL,
    registration_number TEXT,
    formation_date DATE DEFAULT CURRENT_DATE,
    address TEXT,
    village TEXT NOT NULL,
    taluka TEXT NOT NULL,
    district TEXT NOT NULL,
    pincode VARCHAR(10),
    mobile TEXT NOT NULL,
    email TEXT,
    president_name TEXT,
    secretary_name TEXT,
    treasurer_name TEXT,
    logo_url TEXT,
    monthly_savings_amount NUMERIC(12, 2) DEFAULT 200.00,
    savings_due_day INT DEFAULT 10,
    default_loan_interest_rate NUMERIC(5, 2) DEFAULT 12.00,
    late_fee_per_day NUMERIC(10, 2) DEFAULT 5.00,
    meeting_absence_fine NUMERIC(10, 2) DEFAULT 50.00,
    status record_status_type DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 4. USER PROFILES & SUB-USERS (SUPABASE AUTH LINKED)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    mobile TEXT NOT NULL,
    email TEXT,
    profile_photo_url TEXT,
    role user_role_type NOT NULL DEFAULT 'employee',
    status record_status_type NOT NULL DEFAULT 'active',
    joining_date DATE DEFAULT CURRENT_DATE,
    is_main_admin BOOLEAN DEFAULT false,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (group_id, mobile)
);

-- ==============================================================================
-- 5. GRANULAR ROLE PERMISSIONS MATRIX
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.user_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    module TEXT NOT NULL,
    can_view BOOLEAN DEFAULT false,
    can_add BOOLEAN DEFAULT false,
    can_edit BOOLEAN DEFAULT false,
    can_delete BOOLEAN DEFAULT false,
    can_approve BOOLEAN DEFAULT false,
    can_print BOOLEAN DEFAULT false,
    can_export BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (user_id, module)
);

-- ==============================================================================
-- 6. MEMBERS MANAGEMENT
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_code TEXT NOT NULL,
    full_name TEXT NOT NULL,
    photo_url TEXT,
    mobile_number TEXT NOT NULL,
    alternate_mobile TEXT,
    date_of_birth DATE,
    gender TEXT DEFAULT 'Female',
    address TEXT,
    village TEXT,
    taluka TEXT,
    district TEXT,
    pincode VARCHAR(10),
    aadhaar_last_four VARCHAR(4),
    joining_date DATE DEFAULT CURRENT_DATE,
    occupation TEXT,
    education TEXT,
    nominee_name TEXT,
    nominee_relation TEXT,
    nominee_mobile TEXT,
    bank_name TEXT,
    account_number TEXT,
    ifsc TEXT,
    account_holder_name TEXT,
    status record_status_type DEFAULT 'active',
    remarks TEXT,
    created_by UUID REFERENCES public.profiles(id),
    updated_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (group_id, member_code)
);

-- ==============================================================================
-- 7. SAVINGS MANAGEMENT
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    savings_date DATE NOT NULL DEFAULT CURRENT_DATE,
    savings_type savings_category_type NOT NULL DEFAULT 'monthly',
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_mode payment_mode_type NOT NULL DEFAULT 'cash',
    transaction_number TEXT,
    receipt_number TEXT NOT NULL,
    collected_by UUID REFERENCES public.profiles(id),
    remarks TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 8. LOANS & EMI MANAGEMENT
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    loan_code TEXT NOT NULL,
    application_date DATE NOT NULL DEFAULT CURRENT_DATE,
    loan_type TEXT NOT NULL DEFAULT 'personal',
    requested_amount NUMERIC(12, 2) NOT NULL CHECK (requested_amount > 0),
    approved_amount NUMERIC(12, 2) NOT NULL CHECK (approved_amount >= 0),
    purpose TEXT,
    interest_rate NUMERIC(5, 2) NOT NULL,
    interest_type TEXT NOT NULL DEFAULT 'reducing',
    loan_period_months INT NOT NULL CHECK (loan_period_months > 0),
    emi_amount NUMERIC(12, 2) NOT NULL CHECK (emi_amount >= 0),
    number_of_emis INT NOT NULL CHECK (number_of_emis > 0),
    first_emi_date DATE NOT NULL,
    approval_date DATE,
    disbursement_date DATE,
    approved_by UUID REFERENCES public.profiles(id),
    guarantor_1_id UUID REFERENCES public.members(id),
    guarantor_2_id UUID REFERENCES public.members(id),
    outstanding_principal NUMERIC(12, 2) NOT NULL DEFAULT 0,
    outstanding_interest NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_repaid NUMERIC(12, 2) NOT NULL DEFAULT 0,
    settlement_date DATE,
    status loan_status_type NOT NULL DEFAULT 'applied',
    remarks TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (group_id, loan_code)
);

CREATE TABLE IF NOT EXISTS public.loan_emis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    loan_id UUID NOT NULL REFERENCES public.loans(id) ON DELETE CASCADE,
    emi_number INT NOT NULL,
    due_date DATE NOT NULL,
    principal NUMERIC(12, 2) NOT NULL DEFAULT 0,
    interest NUMERIC(12, 2) NOT NULL DEFAULT 0,
    emi_amount NUMERIC(12, 2) NOT NULL,
    late_fee NUMERIC(12, 2) DEFAULT 0,
    paid_amount NUMERIC(12, 2) DEFAULT 0,
    payment_date DATE,
    payment_mode payment_mode_type,
    transaction_id TEXT,
    receipt_number TEXT,
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    status emi_status_type NOT NULL DEFAULT 'pending',
    collected_by UUID REFERENCES public.profiles(id),
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (loan_id, emi_number)
);

-- ==============================================================================
-- 9. MEETINGS & ATTENDANCE
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.meetings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    meeting_date DATE NOT NULL,
    meeting_time TIME NOT NULL,
    location TEXT NOT NULL,
    meeting_type TEXT NOT NULL DEFAULT 'monthly',
    agenda TEXT NOT NULL,
    organizer_id UUID REFERENCES public.profiles(id),
    description TEXT,
    minutes_of_meeting TEXT,
    status meeting_status_type DEFAULT 'scheduled',
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meeting_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    meeting_id UUID NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    status attendance_status_type NOT NULL DEFAULT 'present',
    arrival_time TIME,
    remarks TEXT,
    marked_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (meeting_id, member_id)
);

-- ==============================================================================
-- 10. VOTING & RESOLUTIONS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.resolutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    meeting_id UUID REFERENCES public.meetings(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    proposed_by UUID REFERENCES public.members(id),
    resolution_date DATE DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'proposed',
    votes_yes INT DEFAULT 0,
    votes_no INT DEFAULT 0,
    votes_abstain INT DEFAULT 0,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.resolution_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    resolution_id UUID NOT NULL REFERENCES public.resolutions(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    vote TEXT NOT NULL CHECK (vote IN ('yes', 'no', 'abstain')),
    voted_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (resolution_id, member_id)
);

-- ==============================================================================
-- 11. INCOMES & EXPENSES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.incomes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    income_date DATE NOT NULL DEFAULT CURRENT_DATE,
    category TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_mode payment_mode_type NOT NULL DEFAULT 'cash',
    received_from TEXT NOT NULL,
    transaction_number TEXT,
    receipt_number TEXT,
    description TEXT,
    attachment_url TEXT,
    entered_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    category TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_mode payment_mode_type NOT NULL DEFAULT 'cash',
    paid_to TEXT NOT NULL,
    bill_number TEXT,
    description TEXT,
    attachment_url TEXT,
    approved_by UUID REFERENCES public.profiles(id),
    entered_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 12. BANK & CASH MANAGEMENT
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    bank_name TEXT NOT NULL,
    branch TEXT NOT NULL,
    account_number TEXT NOT NULL,
    ifsc TEXT NOT NULL,
    account_type TEXT NOT NULL DEFAULT 'savings',
    account_holder TEXT NOT NULL,
    opening_balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    current_balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    is_primary BOOLEAN DEFAULT false,
    status record_status_type DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (group_id, account_number)
);

CREATE TABLE IF NOT EXISTS public.bank_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    bank_account_id UUID NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    type TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'interest', 'charge')),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    deposit_slip_or_cheque_no TEXT,
    transaction_number TEXT,
    purpose TEXT,
    performed_by TEXT,
    approved_by UUID REFERENCES public.profiles(id),
    balance_after NUMERIC(14, 2) NOT NULL,
    remarks TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cash_book (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    type TEXT NOT NULL CHECK (type IN ('cash_in', 'cash_out')),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    balance_after NUMERIC(14, 2) NOT NULL,
    description TEXT NOT NULL,
    reference_module TEXT,
    reference_id UUID,
    entered_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bank_reconciliations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    bank_account_id UUID NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
    reconciliation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    app_balance NUMERIC(14, 2) NOT NULL,
    bank_statement_balance NUMERIC(14, 2) NOT NULL,
    difference NUMERIC(14, 2) NOT NULL,
    status TEXT DEFAULT 'matched',
    remarks TEXT,
    reconciled_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 13. PRODUCTS & INVENTORY / STOCK
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.product_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.product_categories(id) ON DELETE SET NULL,
    product_code TEXT NOT NULL,
    product_name TEXT NOT NULL,
    category_name TEXT,
    description TEXT,
    unit TEXT NOT NULL DEFAULT 'kg',
    purchase_cost NUMERIC(10, 2) DEFAULT 0.00,
    production_cost NUMERIC(10, 2) DEFAULT 0.00,
    selling_price NUMERIC(10, 2) NOT NULL,
    minimum_stock NUMERIC(10, 2) DEFAULT 5.00,
    current_stock NUMERIC(10, 2) DEFAULT 0.00,
    product_image_url TEXT,
    status record_status_type DEFAULT 'active',
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (group_id, product_code)
);

CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    mobile TEXT,
    email TEXT,
    address TEXT,
    gst_number TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
    transaction_type stock_transaction_type NOT NULL,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL,
    purchase_rate NUMERIC(10, 2),
    total_amount NUMERIC(12, 2),
    batch_number TEXT,
    expiry_date DATE,
    invoice_number TEXT,
    reason TEXT,
    authorized_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 14. CUSTOMERS & SALES / BILLING
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    mobile TEXT NOT NULL,
    email TEXT,
    address TEXT,
    gst_number TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    invoice_number TEXT NOT NULL,
    sale_date DATE NOT NULL DEFAULT CURRENT_DATE,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    discount NUMERIC(12, 2) DEFAULT 0.00,
    tax NUMERIC(12, 2) DEFAULT 0.00,
    total_amount NUMERIC(12, 2) NOT NULL,
    paid_amount NUMERIC(12, 2) DEFAULT 0.00,
    remaining_amount NUMERIC(12, 2) DEFAULT 0.00,
    payment_status due_status_type NOT NULL DEFAULT 'paid',
    payment_mode payment_mode_type NOT NULL DEFAULT 'cash',
    salesperson_id UUID REFERENCES public.profiles(id),
    remarks TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (group_id, invoice_number)
);

CREATE TABLE IF NOT EXISTS public.sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL,
    cost_price NUMERIC(10, 2) DEFAULT 0.00,
    total_price NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 15. MEMBER BUSINESS MANAGEMENT
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.member_businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    business_type TEXT NOT NULL,
    investment NUMERIC(12, 2) DEFAULT 0.00,
    monthly_production TEXT,
    monthly_sales NUMERIC(12, 2) DEFAULT 0.00,
    monthly_expenses NUMERIC(12, 2) DEFAULT 0.00,
    monthly_profit NUMERIC(12, 2) DEFAULT 0.00,
    start_date DATE,
    status record_status_type DEFAULT 'active',
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 16. CONTRIBUTIONS & FINES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    contribution_date DATE NOT NULL DEFAULT CURRENT_DATE,
    contribution_type TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_mode payment_mode_type NOT NULL DEFAULT 'cash',
    receipt_number TEXT NOT NULL,
    purpose TEXT,
    remarks TEXT,
    collected_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    fine_date DATE NOT NULL DEFAULT CURRENT_DATE,
    fine_type TEXT NOT NULL,
    reason TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    paid_amount NUMERIC(10, 2) DEFAULT 0.00,
    pending_amount NUMERIC(10, 2) NOT NULL,
    status due_status_type NOT NULL DEFAULT 'pending',
    paid_date DATE,
    payment_mode payment_mode_type,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 17. GOVERNMENT SCHEMES & APPLICATIONS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.government_schemes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    scheme_name TEXT NOT NULL,
    department TEXT NOT NULL,
    description TEXT,
    eligibility TEXT,
    benefit_amount NUMERIC(12, 2),
    start_date DATE,
    end_date DATE,
    required_documents TEXT,
    status record_status_type DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.scheme_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    scheme_id UUID NOT NULL REFERENCES public.government_schemes(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    application_number TEXT NOT NULL,
    application_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'applied',
    approved_amount NUMERIC(12, 2),
    approval_date DATE,
    remarks TEXT,
    submitted_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 18. DOCUMENT MANAGEMENT (SUPABASE STORAGE BACKED)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    document_name TEXT NOT NULL,
    document_type document_type_enum NOT NULL DEFAULT 'other',
    document_number TEXT,
    issue_date DATE,
    expiry_date DATE,
    file_url TEXT NOT NULL,
    file_size_bytes BIGINT,
    verification_status verification_status_type DEFAULT 'pending',
    verified_by UUID REFERENCES public.profiles(id),
    verified_at TIMESTAMPTZ,
    remarks TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 19. TRAININGS & SKILLS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.trainings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    training_name TEXT NOT NULL,
    trainer TEXT NOT NULL,
    organization TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    location TEXT,
    description TEXT,
    skills_taught TEXT,
    certificate_available BOOLEAN DEFAULT false,
    status meeting_status_type DEFAULT 'scheduled',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.training_attendances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    training_id UUID NOT NULL REFERENCES public.trainings(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    is_completed BOOLEAN DEFAULT false,
    skill_level TEXT,
    certificate_url TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (training_id, member_id)
);

-- ==============================================================================
-- 20. EVENTS & ACTIVITIES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    event_name TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_date DATE NOT NULL,
    event_time TIME,
    location TEXT,
    organizer TEXT,
    budget NUMERIC(12, 2) DEFAULT 0.00,
    actual_expense NUMERIC(12, 2) DEFAULT 0.00,
    description TEXT,
    status meeting_status_type DEFAULT 'scheduled',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.event_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    attended BOOLEAN DEFAULT false,
    role TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (event_id, member_id)
);

-- ==============================================================================
-- 21. CENTRAL DUES & PENDING PAYMENTS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.dues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    payment_type TEXT NOT NULL,
    reference_id UUID,
    due_date DATE NOT NULL,
    due_amount NUMERIC(12, 2) NOT NULL,
    paid_amount NUMERIC(12, 2) DEFAULT 0.00,
    remaining_amount NUMERIC(12, 2) NOT NULL,
    late_fee NUMERIC(12, 2) DEFAULT 0.00,
    status due_status_type NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 22. NOTIFICATIONS & REMINDERS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    priority notification_priority_type DEFAULT 'medium',
    due_date DATE,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 23. AUDIT & ACTIVITY LOG
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name TEXT,
    user_role TEXT,
    module TEXT NOT NULL,
    action TEXT NOT NULL,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    description TEXT,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 24. GROUP SETTINGS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE UNIQUE,
    language TEXT DEFAULT 'mr',
    currency TEXT DEFAULT 'INR',
    currency_symbol TEXT DEFAULT '₹',
    date_format TEXT DEFAULT 'dd-MM-yyyy',
    receipt_prefix TEXT DEFAULT 'REC',
    invoice_prefix TEXT DEFAULT 'INV',
    voucher_prefix TEXT DEFAULT 'VCH',
    receipt_footer_note TEXT DEFAULT 'धन्यवाद! Empowering Women, Building Better Tomorrows.',
    otp_login_enabled BOOLEAN DEFAULT true,
    pin_lock_enabled BOOLEAN DEFAULT false,
    biometric_enabled BOOLEAN DEFAULT false,
    session_timeout_minutes INT DEFAULT 30,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- 25. PERFORMANCE INDEXES
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_profiles_group ON public.profiles(group_id);
CREATE INDEX IF NOT EXISTS idx_members_group ON public.members(group_id);
CREATE INDEX IF NOT EXISTS idx_members_mobile ON public.members(mobile_number);
CREATE INDEX IF NOT EXISTS idx_savings_group_member ON public.savings(group_id, member_id);
CREATE INDEX IF NOT EXISTS idx_savings_date ON public.savings(savings_date);
CREATE INDEX IF NOT EXISTS idx_loans_group_member ON public.loans(group_id, member_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON public.loans(status);
CREATE INDEX IF NOT EXISTS idx_loan_emis_loan ON public.loan_emis(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_emis_status ON public.loan_emis(status);
CREATE INDEX IF NOT EXISTS idx_meetings_group_date ON public.meetings(group_id, meeting_date);
CREATE INDEX IF NOT EXISTS idx_incomes_group_date ON public.incomes(group_id, income_date);
CREATE INDEX IF NOT EXISTS idx_expenses_group_date ON public.expenses(group_id, expense_date);
CREATE INDEX IF NOT EXISTS idx_bank_tx_account ON public.bank_transactions(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_cash_book_group_date ON public.cash_book(group_id, entry_date);
CREATE INDEX IF NOT EXISTS idx_products_group ON public.products(group_id);
CREATE INDEX IF NOT EXISTS idx_sales_group ON public.sales(group_id);
CREATE INDEX IF NOT EXISTS idx_dues_group_status ON public.dues(group_id, status);
CREATE INDEX IF NOT EXISTS idx_notifications_group_user ON public.notifications(group_id, user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_audit_logs_group ON public.audit_logs(group_id, created_at DESC);

-- ==============================================================================
-- 26. DATABASE TRIGGERS & AUTOMATED LOGIC
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ 
DECLARE 
    tbl text;
BEGIN
    FOR tbl IN 
        SELECT unnest(ARRAY[
            'groups', 'profiles', 'user_permissions', 'members', 'savings',
            'loans', 'loan_emis', 'meetings', 'meeting_attendance', 'resolutions',
            'incomes', 'expenses', 'bank_accounts', 'products', 'sales',
            'member_businesses', 'fines', 'government_schemes', 'scheme_applications',
            'documents', 'dues', 'settings'
        ])
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS set_timestamp_%I ON public.%I;', tbl, tbl);
        EXECUTE format('CREATE TRIGGER set_timestamp_%I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.trigger_set_timestamp();', tbl, tbl);
    END LOOP;
END $$;

-- Sync Inventory Stock on Stock Transactions
CREATE OR REPLACE FUNCTION public.trg_sync_product_stock_on_transaction()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF NEW.transaction_type = 'stock_in' OR NEW.transaction_type = 'return' THEN
            UPDATE public.products 
            SET current_stock = current_stock + NEW.quantity 
            WHERE id = NEW.product_id;
        ELSIF NEW.transaction_type = 'stock_out' OR NEW.transaction_type = 'wastage' THEN
            UPDATE public.products 
            SET current_stock = GREATEST(0, current_stock - NEW.quantity) 
            WHERE id = NEW.product_id;
        ELSIF NEW.transaction_type = 'adjustment' THEN
            UPDATE public.products 
            SET current_stock = NEW.quantity 
            WHERE id = NEW.product_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_tx ON public.stock_transactions;
CREATE TRIGGER trg_stock_tx
AFTER INSERT ON public.stock_transactions
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_product_stock_on_transaction();

-- Sync Stock on Sale Items
CREATE OR REPLACE FUNCTION public.trg_sync_sale_item()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.products 
        SET current_stock = GREATEST(0, current_stock - NEW.quantity) 
        WHERE id = NEW.product_id;

        INSERT INTO public.stock_transactions (
            group_id, product_id, transaction_type, transaction_date,
            quantity, unit, purchase_rate, total_amount, reason
        )
        SELECT 
            s.group_id, NEW.product_id, 'stock_out', s.sale_date,
            NEW.quantity, p.unit, NEW.unit_price, NEW.total_price, 'Sale Invoice #' || s.invoice_number
        FROM public.sales s
        JOIN public.products p ON p.id = NEW.product_id
        WHERE s.id = NEW.sale_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sale_item_stock ON public.sale_items;
CREATE TRIGGER trg_sale_item_stock
AFTER INSERT ON public.sale_items
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_sale_item();

-- Sync Bank Account Balance on Bank Transactions
CREATE OR REPLACE FUNCTION public.trg_sync_bank_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF NEW.type IN ('deposit', 'interest') THEN
            UPDATE public.bank_accounts 
            SET current_balance = current_balance + NEW.amount 
            WHERE id = NEW.bank_account_id;
        ELSIF NEW.type IN ('withdrawal', 'charge') THEN
            UPDATE public.bank_accounts 
            SET current_balance = current_balance - NEW.amount 
            WHERE id = NEW.bank_account_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bank_balance ON public.bank_transactions;
CREATE TRIGGER trg_bank_balance
AFTER INSERT ON public.bank_transactions
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_bank_balance();

-- Sync Loan Repayment on EMI Payment
CREATE OR REPLACE FUNCTION public.trg_sync_loan_on_emi_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'paid' AND (OLD.status IS DISTINCT FROM 'paid')) THEN
        UPDATE public.loans
        SET 
            outstanding_principal = GREATEST(0, outstanding_principal - NEW.principal),
            outstanding_interest = GREATEST(0, outstanding_interest - NEW.interest),
            total_repaid = total_repaid + NEW.paid_amount,
            status = CASE 
                WHEN (outstanding_principal - NEW.principal) <= 0 THEN 'closed'::loan_status_type
                ELSE status
            END,
            settlement_date = CASE 
                WHEN (outstanding_principal - NEW.principal) <= 0 THEN CURRENT_DATE 
                ELSE settlement_date 
            END
        WHERE id = NEW.loan_id;

        UPDATE public.dues
        SET 
            paid_amount = NEW.paid_amount,
            remaining_amount = 0,
            status = 'paid'
        WHERE reference_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_loan_emi_payment ON public.loan_emis;
CREATE TRIGGER trg_loan_emi_payment
AFTER UPDATE ON public.loan_emis
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_loan_on_emi_payment();

-- ==============================================================================
-- 27. SECURITY & RLS HELPER FUNCTIONS
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_auth_group_id()
RETURNS UUID AS $$
    SELECT group_id FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_main_admin()
RETURNS BOOLEAN AS $$
    SELECT COALESCE(is_main_admin, false) OR role = 'admin'
    FROM public.profiles 
    WHERE id = auth.uid() 
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.has_permission(p_module TEXT, p_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_permitted BOOLEAN;
BEGIN
    SELECT COALESCE(is_main_admin, false) OR role = 'admin' INTO v_is_admin
    FROM public.profiles 
    WHERE id = auth.uid();

    IF v_is_admin IS TRUE THEN
        RETURN TRUE;
    END IF;

    EXECUTE format('
        SELECT COALESCE(can_%I, false)
        FROM public.user_permissions
        WHERE user_id = auth.uid() AND module = $1
        LIMIT 1', p_action)
    INTO v_permitted
    USING p_module;

    RETURN COALESCE(v_permitted, false);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ==============================================================================
-- 28. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_emis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resolutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resolution_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_book ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.government_schemes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheme_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_attendances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- GROUPS RLS
CREATE POLICY "Users can view their own group"
    ON public.groups FOR SELECT
    USING (id = public.get_auth_group_id());

CREATE POLICY "Admin can update own group"
    ON public.groups FOR UPDATE
    USING (id = public.get_auth_group_id() AND public.is_main_admin());

-- PROFILES RLS
CREATE POLICY "Group users can view profiles in same group"
    ON public.profiles FOR SELECT
    USING (group_id = public.get_auth_group_id());

CREATE POLICY "Admin can insert sub-users in group"
    ON public.profiles FOR INSERT
    WITH CHECK (group_id = public.get_auth_group_id() AND (public.is_main_admin() OR auth.uid() = id));

CREATE POLICY "Admin or user can update profile"
    ON public.profiles FOR UPDATE
    USING (group_id = public.get_auth_group_id() AND (public.is_main_admin() OR auth.uid() = id));

CREATE POLICY "Admin can delete profile in group"
    ON public.profiles FOR DELETE
    USING (group_id = public.get_auth_group_id() AND public.is_main_admin());

-- USER PERMISSIONS RLS
CREATE POLICY "Users view permissions in same group"
    ON public.user_permissions FOR SELECT
    USING (group_id = public.get_auth_group_id());

CREATE POLICY "Admin can manage permissions"
    ON public.user_permissions FOR ALL
    USING (group_id = public.get_auth_group_id() AND public.is_main_admin());

-- Tenant-isolated tables policies
DO $$
DECLARE
    t text;
    has_group_col boolean;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
          AND table_name NOT IN ('groups', 'profiles', 'user_permissions', 'sale_items')
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = t AND column_name = 'group_id'
        ) INTO has_group_col;

        IF has_group_col THEN
            EXECUTE format('DROP POLICY IF EXISTS "%s_select_policy" ON public.%I;', t, t);
            EXECUTE format('CREATE POLICY "%s_select_policy" ON public.%I FOR SELECT USING (group_id = public.get_auth_group_id());', t, t);

            EXECUTE format('DROP POLICY IF EXISTS "%s_insert_policy" ON public.%I;', t, t);
            EXECUTE format('CREATE POLICY "%s_insert_policy" ON public.%I FOR INSERT WITH CHECK (group_id = public.get_auth_group_id());', t, t);

            EXECUTE format('DROP POLICY IF EXISTS "%s_update_policy" ON public.%I;', t, t);
            EXECUTE format('CREATE POLICY "%s_update_policy" ON public.%I FOR UPDATE USING (group_id = public.get_auth_group_id());', t, t);

            EXECUTE format('DROP POLICY IF EXISTS "%s_delete_policy" ON public.%I;', t, t);
            EXECUTE format('CREATE POLICY "%s_delete_policy" ON public.%I FOR DELETE USING (group_id = public.get_auth_group_id());', t, t);
        END IF;
    END LOOP;
END $$;

-- sale_items RLS
CREATE POLICY "sale_items_select" ON public.sale_items FOR SELECT
USING (EXISTS (SELECT 1 FROM public.sales s WHERE s.id = sale_items.sale_id AND s.group_id = public.get_auth_group_id()));

CREATE POLICY "sale_items_insert" ON public.sale_items FOR INSERT
WITH CHECK (EXISTS (SELECT 1 FROM public.sales s WHERE s.id = sale_items.sale_id AND s.group_id = public.get_auth_group_id()));

CREATE POLICY "sale_items_update" ON public.sale_items FOR UPDATE
USING (EXISTS (SELECT 1 FROM public.sales s WHERE s.id = sale_items.sale_id AND s.group_id = public.get_auth_group_id()));

CREATE POLICY "sale_items_delete" ON public.sale_items FOR DELETE
USING (EXISTS (SELECT 1 FROM public.sales s WHERE s.id = sale_items.sale_id AND s.group_id = public.get_auth_group_id()));

-- ==============================================================================
-- 29. REAL-TIME DASHBOARD & METRICS RPC FUNCTION
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_dashboard_metrics(p_group_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_total_members INT;
    v_total_savings NUMERIC(14, 2);
    v_active_loans NUMERIC(14, 2);
    v_pending_emi_count INT;
    v_bank_balance NUMERIC(14, 2);
    v_cash_in_hand NUMERIC(14, 2);
    v_total_income NUMERIC(14, 2);
    v_total_expenses NUMERIC(14, 2);
    v_total_sales NUMERIC(14, 2);
    v_total_profit NUMERIC(14, 2);
    v_upcoming_meeting JSONB;
    v_result JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total_members
    FROM public.members
    WHERE group_id = p_group_id AND status = 'active';

    SELECT COALESCE(SUM(amount), 0) INTO v_total_savings
    FROM public.savings
    WHERE group_id = p_group_id;

    SELECT COALESCE(SUM(outstanding_principal), 0) INTO v_active_loans
    FROM public.loans
    WHERE group_id = p_group_id AND status = 'disbursed';

    SELECT COUNT(*) INTO v_pending_emi_count
    FROM public.loan_emis
    WHERE group_id = p_group_id AND status IN ('pending', 'overdue');

    SELECT COALESCE(SUM(current_balance), 0) INTO v_bank_balance
    FROM public.bank_accounts
    WHERE group_id = p_group_id AND status = 'active';

    SELECT COALESCE(
        (SELECT balance_after FROM public.cash_book WHERE group_id = p_group_id ORDER BY created_at DESC LIMIT 1),
        0.00
    ) INTO v_cash_in_hand;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_income
    FROM public.incomes
    WHERE group_id = p_group_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
    FROM public.expenses
    WHERE group_id = p_group_id;

    SELECT COALESCE(SUM(total_amount), 0) INTO v_total_sales
    FROM public.sales
    WHERE group_id = p_group_id;

    v_total_profit := (v_total_sales + v_total_income) - v_total_expenses;

    SELECT jsonb_build_object(
        'id', id,
        'meeting_date', meeting_date,
        'meeting_time', meeting_time,
        'location', location,
        'agenda', agenda
    ) INTO v_upcoming_meeting
    FROM public.meetings
    WHERE group_id = p_group_id AND meeting_date >= CURRENT_DATE AND status = 'scheduled'
    ORDER BY meeting_date ASC, meeting_time ASC
    LIMIT 1;

    v_result := jsonb_build_object(
        'total_members', v_total_members,
        'total_savings', v_total_savings,
        'active_loans', v_active_loans,
        'pending_emis', v_pending_emi_count,
        'bank_balance', v_bank_balance,
        'cash_in_hand', v_cash_in_hand,
        'total_income', v_total_income,
        'total_expenses', v_total_expenses,
        'total_sales', v_total_sales,
        'total_profit', v_total_profit,
        'upcoming_meeting', v_upcoming_meeting
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ==============================================================================
-- 30. REUSABLE AUDIT LOGGER HELPER
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.log_audit_event(
    p_group_id UUID,
    p_module TEXT,
    p_action TEXT,
    p_record_id UUID,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
    v_user_name TEXT;
    v_user_role TEXT;
BEGIN
    SELECT full_name, role::text 
    INTO v_user_name, v_user_role
    FROM public.profiles
    WHERE id = auth.uid();

    INSERT INTO public.audit_logs (
        group_id, user_id, user_name, user_role,
        module, action, record_id, old_values, new_values, description
    ) VALUES (
        p_group_id, auth.uid(), v_user_name, v_user_role,
        p_module, p_action, p_record_id, p_old_values, p_new_values, p_description
    ) RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==============================================================================
-- SUPABASE STORAGE BUCKETS & RLS POLICIES
-- ==============================================================================

-- 1. Create Buckets if not existing
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('member-photos', 'member-photos', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('member-documents', 'member-documents', false, 15728640, ARRAY['image/jpeg', 'image/png', 'application/pdf']),
    ('group-assets', 'group-assets', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/svg+xml']),
    ('receipts-invoices', 'receipts-invoices', false, 15728640, ARRAY['application/pdf', 'image/jpeg', 'image/png']),
    ('expense-attachments', 'expense-attachments', false, 15728640, ARRAY['image/jpeg', 'image/png', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS Policies
-- Member Photos (Public read, authenticated member in group write)
CREATE POLICY "Public Member Photos Read"
ON storage.objects FOR SELECT
USING (bucket_id = 'member-photos');

CREATE POLICY "Authenticated Group Member Photos Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'member-photos' AND 
    (storage.foldername(name))[1] = public.get_auth_group_id()::text
);

CREATE POLICY "Authenticated Group Member Photos Delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'member-photos' AND 
    (storage.foldername(name))[1] = public.get_auth_group_id()::text
);

-- Member Documents (Tenant isolated)
CREATE POLICY "Tenant Group Member Documents Read"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'member-documents' AND 
    (storage.foldername(name))[1] = public.get_auth_group_id()::text
);

CREATE POLICY "Tenant Group Member Documents Insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'member-documents' AND 
    (storage.foldername(name))[1] = public.get_auth_group_id()::text
);

-- Group Assets (Public read, admin write)
CREATE POLICY "Public Group Assets Read"
ON storage.objects FOR SELECT
USING (bucket_id = 'group-assets');

CREATE POLICY "Admin Group Assets Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'group-assets' AND 
    (storage.foldername(name))[1] = public.get_auth_group_id()::text AND
    public.is_main_admin()
);

-- Receipts & Invoices (Tenant read & write)
CREATE POLICY "Tenant Receipts Invoices Read"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'receipts-invoices' AND 
    (storage.foldername(name))[1] = public.get_auth_group_id()::text
);

CREATE POLICY "Tenant Receipts Invoices Insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'receipts-invoices' AND 
    (storage.foldername(name))[1] = public.get_auth_group_id()::text
);


-- ==============================================================================
-- SEED SAMPLE DATA: Matches the Exact UI Poster
-- Sakhi Mahila Bachat Gat, Sangola, Tal - Sangola, Dist - Solapur
-- ==============================================================================

DO $$
DECLARE
    v_group_id UUID := '11111111-1111-1111-1111-111111111111'::UUID;
    v_admin_id UUID := '22222222-2222-2222-2222-222222222222'::UUID;
    v_sunita_id UUID := '33333333-3333-3333-3333-333333333333'::UUID;
    v_meena_id UUID := '44444444-4444-4444-4444-444444444444'::UUID;
    v_kavita_id UUID := '55555555-5555-5555-5555-555555555555'::UUID;
    v_m_sunita UUID := 'a1111111-1111-1111-1111-111111111111'::UUID;
    v_m_meena UUID := 'a2222222-2222-2222-2222-222222222222'::UUID;
    v_m_lata UUID := 'a3333333-3333-3333-3333-333333333333'::UUID;
    v_m_kavita UUID := 'a4444444-4444-4444-4444-444444444444'::UUID;
    v_m_asha UUID := 'a5555555-5555-5555-5555-555555555555'::UUID;
    v_bank_acc UUID := 'b1111111-1111-1111-1111-111111111111'::UUID;
    v_loan_id UUID := 'c1111111-1111-1111-1111-111111111111'::UUID;
    v_p_papad UUID := 'd1111111-1111-1111-1111-111111111111'::UUID;
    v_p_pickle UUID := 'd2222222-2222-2222-2222-222222222222'::UUID;
    v_p_masala UUID := 'd3333333-3333-3333-3333-333333333333'::UUID;
    v_p_handicraft UUID := 'd4444444-4444-4444-4444-444444444444'::UUID;
    v_p_clothes UUID := 'd5555555-5555-5555-5555-555555555555'::UUID;
BEGIN
    -- 1. Create Group
    INSERT INTO public.groups (
        id, group_name, registration_number, formation_date, address, village, taluka, district, pincode,
        mobile, email, president_name, secretary_name, treasurer_name, monthly_savings_amount
    ) VALUES (
        v_group_id, 'Sakhi Mahila Bachat Gat', 'MAH-MH-1234', '2020-01-15',
        'Near Gram Panchayat', 'Sangola', 'Sangola', 'Solapur', '413307',
        '9876543210', 'sakhi.sangola@gmail.com', 'Sunita Pawar', 'Meena Jadhav', 'Kavita Shinde', 500.00
    ) ON CONFLICT (id) DO UPDATE SET group_name = EXCLUDED.group_name;

    -- 2. Create Group Settings
    INSERT INTO public.settings (
        group_id, language, currency, currency_symbol, date_format,
        receipt_prefix, invoice_prefix, voucher_prefix, otp_login_enabled
    ) VALUES (
        v_group_id, 'mr', 'INR', '₹', 'dd-MM-yyyy', 'REC', 'INV', 'VCH', true
    ) ON CONFLICT (group_id) DO NOTHING;

    -- 3. Members
    INSERT INTO public.members (
        id, group_id, member_code, full_name, mobile_number, date_of_birth,
        address, village, taluka, district, education, nominee_name, nominee_relation,
        bank_name, account_number, ifsc, account_holder_name, status
    ) VALUES 
    (v_m_sunita, v_group_id, 'MBG01', 'Sunita Pawar', '9876543210', '1985-05-12', 'A/P Sangola', 'Sangola', 'Sangola', 'Solapur', '10th Pass', 'Rekha Pawar', 'Husband', 'State Bank of India', '1234567890', 'SBIN0001234', 'Sunita Pawar', 'active'),
    (v_m_meena, v_group_id, 'MBG02', 'Meena Jadhav', '98765432109', '1988-08-20', 'A/P Sangola', 'Sangola', 'Sangola', 'Solapur', '12th Pass', 'Ramesh Jadhav', 'Husband', 'Bank of Maharashtra', '2345678901', 'MAHB0000456', 'Meena Jadhav', 'active'),
    (v_m_lata, v_group_id, 'MBG03', 'Lata More', '917654321890', '1990-11-15', 'A/P Sangola', 'Sangola', 'Sangola', 'Solapur', 'BA Graduate', 'Suresh More', 'Husband', 'Bank of Baroda', '3456789012', 'BARB0SANGOL', 'Lata More', 'active'),
    (v_m_kavita, v_group_id, 'MBG04', 'Kavita Shinde', '9876543210', '1992-03-04', 'A/P Sangola', 'Sangola', 'Sangola', 'Solapur', '10th Pass', 'Anil Shinde', 'Husband', 'State Bank of India', '4567890123', 'SBIN0001234', 'Kavita Shinde', 'active'),
    (v_m_asha, v_group_id, 'MBG05', 'Asha Patil', '94126109876', '1987-07-28', 'A/P Sangola', 'Sangola', 'Sangola', 'Solapur', '12th Pass', 'Vikas Patil', 'Husband', 'Canara Bank', '5678901234', 'CNRB0001890', 'Asha Patil', 'active')
    ON CONFLICT (id) DO NOTHING;

    -- 4. Bank Accounts
    INSERT INTO public.bank_accounts (
        id, group_id, bank_name, branch, account_number, ifsc, account_type,
        account_holder, opening_balance, current_balance, is_primary, status
    ) VALUES (
        v_bank_acc, v_group_id, 'State Bank of India', 'Sangola Branch', '1234567890',
        'SBIN0001234', 'savings', 'Sakhi Mahila Bachat Gat', 200000.00, 250000.00, true, 'active'
    ) ON CONFLICT (id) DO NOTHING;

    -- 5. Cash Book Entry (Cash in hand ₹35,000)
    INSERT INTO public.cash_book (
        group_id, entry_date, type, amount, balance_after, description, reference_module
    ) VALUES (
        v_group_id, CURRENT_DATE, 'cash_in', 35000.00, 35000.00, 'Monthly member cash collections & reserves', 'savings'
    );

    -- 6. Monthly Savings (Matches Dashboard Total ₹1,25,000)
    INSERT INTO public.savings (
        group_id, member_id, savings_date, savings_type, amount, payment_mode, receipt_number, remarks
    ) VALUES 
    (v_group_id, v_m_sunita, '2024-05-09', 'monthly', 500.00, 'cash', 'REC-001', 'May Monthly Savings'),
    (v_group_id, v_m_meena, '2024-05-09', 'monthly', 500.00, 'cash', 'REC-002', 'May Monthly Savings'),
    (v_group_id, v_m_lata, '2024-05-09', 'monthly', 500.00, 'cash', 'REC-003', 'May Monthly Savings'),
    (v_group_id, v_m_kavita, '2024-05-09', 'monthly', 500.00, 'cash', 'REC-004', 'May Monthly Savings'),
    (v_group_id, v_m_asha, '2024-05-09', 'monthly', 500.00, 'cash', 'REC-005', 'May Monthly Savings');

    -- Cumulative savings balance placeholder
    INSERT INTO public.savings (
        group_id, member_id, savings_date, savings_type, amount, payment_mode, receipt_number, remarks
    ) VALUES (
        v_group_id, v_m_sunita, '2024-04-01', 'special', 122500.00, 'bank_transfer', 'REC-OPEN', 'Cumulative historical savings pool'
    );

    -- 7. Loans (Matches UI: Active Loans ₹75,000, e.g. L001 Sunita Pawar ₹10,000)
    INSERT INTO public.loans (
        id, group_id, member_id, loan_code, application_date, loan_type,
        requested_amount, approved_amount, purpose, interest_rate, interest_type,
        loan_period_months, emi_amount, number_of_emis, first_emi_date,
        approval_date, disbursement_date, outstanding_principal, total_repaid, status
    ) VALUES (
        v_loan_id, v_group_id, v_m_sunita, 'L001', '2024-04-15', 'personal',
        10000.00, 10000.00, 'Small business expansion', 12.00, 'reducing',
        12, 950.00, 12, '2024-05-01', '2024-04-20', '2024-04-25',
        7100.00, 2900.00, 'disbursed'
    ) ON CONFLICT (id) DO NOTHING;

    -- Additional active loans to equal ₹75,000 active loans in dashboard
    INSERT INTO public.loans (
        group_id, member_id, loan_code, application_date, loan_type,
        requested_amount, approved_amount, purpose, interest_rate, interest_type,
        loan_period_months, emi_amount, number_of_emis, first_emi_date,
        approval_date, disbursement_date, outstanding_principal, total_repaid, status
    ) VALUES (
        v_group_id, v_m_meena, 'L002', '2024-04-10', 'business',
        70000.00, 70000.00, 'Papad manufacturing machinery', 12.00, 'reducing',
        24, 3300.00, 24, '2024-05-01', '2024-04-12', '2024-04-15',
        67900.00, 2100.00, 'disbursed'
    );

    -- 8. EMI Schedule for L001 (Matches UI Poster: 01-05 Paid, 01-06 Paid, 01-07 Pending)
    INSERT INTO public.loan_emis (
        group_id, loan_id, emi_number, due_date, principal, interest, emi_amount, paid_amount, payment_date, payment_mode, receipt_number, status
    ) VALUES 
    (v_group_id, v_loan_id, 1, '2024-05-01', 850.00, 100.00, 950.00, 950.00, '2024-05-01', 'cash', 'EMI-001', 'paid'),
    (v_group_id, v_loan_id, 2, '2024-06-01', 860.00, 90.00, 950.00, 950.00, '2024-06-01', 'cash', 'EMI-002', 'paid'),
    (v_group_id, v_loan_id, 3, '2024-07-01', 870.00, 80.00, 950.00, 0.00, NULL, NULL, NULL, 'pending'),
    (v_group_id, v_loan_id, 4, '2024-08-01', 880.00, 70.00, 950.00, 0.00, NULL, NULL, NULL, 'pending'),
    (v_group_id, v_loan_id, 5, '2024-09-01', 890.00, 60.00, 950.00, 0.00, NULL, NULL, NULL, 'pending')
    ON CONFLICT (loan_id, emi_number) DO NOTHING;

    -- 9. Incomes (Matches Dashboard ₹80,000)
    INSERT INTO public.incomes (
        group_id, income_date, category, amount, payment_mode, received_from, description, receipt_number
    ) VALUES 
    (v_group_id, '2024-05-01', 'Product Sales', 5000.00, 'cash', 'Sangola Market Customer', 'Sales of Papad & Pickle', 'INC-001'),
    (v_group_id, '2024-04-15', 'Government Grant', 50000.00, 'bank_transfer', 'MSRLM Project Grant', 'Women Enterprise Subsidy', 'INC-002'),
    (v_group_id, '2024-04-20', 'Membership Fee', 25000.00, 'cash', 'Annual Group Memberships', 'Annual group renewals', 'INC-003');

    -- 10. Expenses (Matches Dashboard ₹55,000)
    INSERT INTO public.expenses (
        group_id, expense_date, category, amount, payment_mode, paid_to, description, bill_number
    ) VALUES 
    (v_group_id, '2024-05-02', 'Raw Material', 32000.00, 'bank_transfer', 'Patil Spices Sangola', 'Purchase of lentils and spices', 'EXP-001'),
    (v_group_id, '2024-05-03', 'Rent', 10000.00, 'cash', 'Kadam Complex', 'Monthly premises rent', 'EXP-002'),
    (v_group_id, '2024-05-04', 'Electricity', 8000.00, 'bank_transfer', 'MSEDCL Sangola', 'Production center electric bill', 'EXP-003'),
    (v_group_id, '2024-05-05', 'Transport', 5000.00, 'cash', 'Raut Transport', 'Delivery to Solapur weekly market', 'EXP-004');

    -- 11. Products (Matches UI Poster list: Papad 100 ₹80, Pickle 50 ₹120, Masala 75 ₹100, Handicraft 30 ₹250, Clothes 20 ₹450)
    INSERT INTO public.products (
        id, group_id, product_code, product_name, category_name, unit,
        purchase_cost, production_cost, selling_price, minimum_stock, current_stock, status
    ) VALUES 
    (v_p_papad, v_group_id, 'PRD-01', 'Papad', 'Food Products', 'packet', 40.00, 50.00, 80.00, 20.00, 100.00, 'active'),
    (v_p_pickle, v_group_id, 'PRD-02', 'Pickle', 'Food Products', 'kg', 60.00, 80.00, 120.00, 15.00, 50.00, 'active'),
    (v_p_masala, v_group_id, 'PRD-03', 'Masala', 'Spices', 'packet', 50.00, 65.00, 100.00, 25.00, 75.00, 'active'),
    (v_p_handicraft, v_group_id, 'PRD-04', 'Handicraft', 'Handicrafts', 'piece', 120.00, 160.00, 250.00, 10.00, 30.00, 'active'),
    (v_p_clothes, v_group_id, 'PRD-05', 'Clothes', 'Textiles', 'piece', 200.00, 280.00, 450.00, 10.00, 20.00, 'active')
    ON CONFLICT (id) DO NOTHING;

    -- 12. Meetings (Matches UI Poster: Upcoming Meeting 12 May 2024 10:00 AM)
    INSERT INTO public.meetings (
        group_id, meeting_date, meeting_time, location, meeting_type, agenda, description, status
    ) VALUES (
        v_group_id, CURRENT_DATE + INTERVAL '3 days', '10:00:00', 'Community Hall, Sangola',
        'monthly', 'Discussion on new project & loan disbursement',
        'Monthly regular Bachat Gat meet and review of loan repayments', 'scheduled'
    );

    -- 13. Central Pending Dues (Matches UI Poster: Total Due ₹8,700)
    INSERT INTO public.dues (
        group_id, member_id, payment_type, due_date, due_amount, paid_amount, remaining_amount, status
    ) VALUES 
    (v_group_id, v_m_lata, 'savings', CURRENT_DATE, 1500.00, 0.00, 1500.00, 'pending'),
    (v_group_id, v_m_sunita, 'loan_emi', CURRENT_DATE, 5200.00, 0.00, 5200.00, 'pending'),
    (v_group_id, v_m_meena, 'fine', CURRENT_DATE, 200.00, 0.00, 200.00, 'pending'),
    (v_group_id, v_m_kavita, 'contribution', CURRENT_DATE, 1800.00, 0.00, 1800.00, 'pending');

    -- 14. Notifications & Reminders (Matches UI Poster: EMI Due, Meeting Reminder, Doc Expiry, Birthday)
    INSERT INTO public.notifications (
        group_id, member_id, title, message, type, priority, due_date, is_read
    ) VALUES 
    (v_group_id, v_m_sunita, 'EMI Due', 'Loan EMI for L001 is due in 2 days', 'emi_due', 'high', CURRENT_DATE + INTERVAL '2 days', false),
    (v_group_id, NULL, 'Meeting Reminder', 'Monthly general meeting scheduled for tomorrow at Community Hall', 'meeting_reminder', 'medium', CURRENT_DATE + INTERVAL '1 day', false),
    (v_group_id, v_m_lata, 'Document Expiry', 'Bank passbook verification pending', 'document_expiry', 'low', CURRENT_DATE + INTERVAL '15 days', false),
    (v_group_id, v_m_asha, 'Birthday Wishes', 'Happy Birthday Asha Patil! Wish you great success.', 'birthday', 'low', CURRENT_DATE + INTERVAL '5 days', false);

END $$;
