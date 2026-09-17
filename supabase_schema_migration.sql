-- ==============================================================================
-- BACHATGAT MANAGEMENT - SUPABASE CLOUD SCHEMA MIGRATION SCRIPT
-- Run this script in the Supabase SQL Editor (Dashboard -> SQL Editor -> New Query)
-- It is completely safe and IDEMPOTENT (can be run multiple times safely).
-- ==============================================================================

-- 1. Create missing table: monthly_collections
CREATE TABLE IF NOT EXISTS public.monthly_collections (
    id TEXT PRIMARY KEY,
    group_id TEXT,
    member_id TEXT NOT NULL,
    loan_id TEXT,
    bank_account_id TEXT,
    collection_date TEXT NOT NULL,
    monthly_saving NUMERIC DEFAULT 0.0,
    required_emi NUMERIC DEFAULT 0.0,
    paid_emi NUMERIC DEFAULT 0.0,
    principal_amount NUMERIC DEFAULT 0.0,
    interest_amount NUMERIC DEFAULT 0.0,
    remaining_emi NUMERIC DEFAULT 0.0,
    total_collection NUMERIC DEFAULT 0.0,
    payment_status TEXT DEFAULT 'paid',
    payment_mode TEXT DEFAULT 'cash',
    reference_no TEXT,
    notes TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- Enable RLS and add open policy for monthly_collections
ALTER TABLE public.monthly_collections ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'monthly_collections' AND policyname = 'Allow all access to monthly_collections'
    ) THEN
        CREATE POLICY "Allow all access to monthly_collections" ON public.monthly_collections
            FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_monthly_collections_group ON public.monthly_collections(group_id);
CREATE INDEX IF NOT EXISTS idx_monthly_collections_member ON public.monthly_collections(member_id);
CREATE INDEX IF NOT EXISTS idx_monthly_collections_date ON public.monthly_collections(collection_date);


-- 2. Create missing table: bonus_settings
CREATE TABLE IF NOT EXISTS public.bonus_settings (
    id TEXT PRIMARY KEY,
    group_id TEXT,
    setting_name TEXT DEFAULT 'Savings Bonus',
    bonus_type TEXT DEFAULT 'percentage_of_savings',
    calculation_method TEXT DEFAULT 'percentage',
    bonus_percentage NUMERIC DEFAULT 5.0,
    fixed_amount NUMERIC DEFAULT 0.0,
    min_eligibility NUMERIC DEFAULT 0.0,
    max_bonus NUMERIC DEFAULT 5000.0,
    effective_from TEXT,
    effective_to TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.bonus_settings ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'bonus_settings' AND policyname = 'Allow all access to bonus_settings'
    ) THEN
        CREATE POLICY "Allow all access to bonus_settings" ON public.bonus_settings
            FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bonus_settings_group_id ON public.bonus_settings(group_id);


-- 3. Create missing table: bonuses
CREATE TABLE IF NOT EXISTS public.bonuses (
    id TEXT PRIMARY KEY,
    group_id TEXT,
    member_id TEXT,
    financial_year TEXT DEFAULT '2025 - 2026',
    from_date TEXT,
    to_date TEXT,
    bonus_type TEXT DEFAULT 'savings',
    basis_amount NUMERIC DEFAULT 0.0,
    bonus_rate NUMERIC DEFAULT 5.0,
    bonus_amount NUMERIC DEFAULT 0.0,
    paid_amount NUMERIC DEFAULT 0.0,
    status TEXT DEFAULT 'draft',
    approved_by TEXT,
    approved_at TEXT,
    payment_date TEXT,
    payment_mode TEXT,
    bank_account_id TEXT,
    transaction_ref TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.bonuses ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'bonuses' AND policyname = 'Allow all access to bonuses'
    ) THEN
        CREATE POLICY "Allow all access to bonuses" ON public.bonuses
            FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bonuses_group_id ON public.bonuses(group_id);
CREATE INDEX IF NOT EXISTS idx_bonuses_member_id ON public.bonuses(member_id);
CREATE INDEX IF NOT EXISTS idx_bonuses_status ON public.bonuses(status);


-- 4. Add missing columns to existing tables (Safe ALTER TABLE ADD COLUMN IF NOT EXISTS)

-- loans table
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS approved_by TEXT;
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS outstanding_interest NUMERIC DEFAULT 0.0;
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS guarantor_1_id TEXT;
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS guarantor_2_id TEXT;

-- loan_emis table
ALTER TABLE public.loan_emis ADD COLUMN IF NOT EXISTS balance NUMERIC DEFAULT 0.0;

-- incomes table
ALTER TABLE public.incomes ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE public.incomes ADD COLUMN IF NOT EXISTS entered_by TEXT;
ALTER TABLE public.incomes ADD COLUMN IF NOT EXISTS transaction_number TEXT;

-- expenses table
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS approved_by TEXT;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS entered_by TEXT;

-- cash_book table
ALTER TABLE public.cash_book ADD COLUMN IF NOT EXISTS entered_by TEXT;

-- bank_accounts table
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS opening_balance_date TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS bank_address TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS mobile_number TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS notes TEXT;

-- members table
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS aadhaar_number TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS pan_number TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS annual_income NUMERIC;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS nominee_age INTEGER;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS branch_name TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS role_in_group TEXT DEFAULT 'सदस्य';
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS signature_url TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS aadhaar_doc_url TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS pan_doc_url TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS passbook_doc_url TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS remarks TEXT;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS account_holder_name TEXT;

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
