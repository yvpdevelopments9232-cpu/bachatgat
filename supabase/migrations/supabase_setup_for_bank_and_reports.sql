-- ==============================================================================
-- SAKHI BACHAT GAT - SUPABASE DATABASE SETUP & MIGRATION SCRIPT
-- Purpose: Complete tables, columns, indexes, and RLS policies for:
--          1. Bank Management Module (bank_accounts, bank_transactions)
--          2. Monthly Savings & Saving Plans (saving_plans, monthly_savings)
--          3. Cross-module Bank tracking (loans, loan_emis, incomes, expenses)
-- Safe to run repeatedly (Idempotent: uses IF NOT EXISTS & ADD COLUMN IF NOT EXISTS)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABLE: bank_accounts (बँक खाती)
-- ------------------------------------------------------------------------------
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
    opening_balance_date DATE DEFAULT CURRENT_DATE,
    current_balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    is_primary BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'active',
    bank_address TEXT,
    mobile_number TEXT,
    email TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (group_id, account_number)
);

-- Ensure all required columns exist in case the table was created by an older migration
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS opening_balance_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS bank_address TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS mobile_number TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

CREATE INDEX IF NOT EXISTS idx_bank_accounts_group ON public.bank_accounts (group_id);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_status ON public.bank_accounts (status);

-- ------------------------------------------------------------------------------
-- 2. TABLE: bank_transactions (बँक व्यवहार - ठेव / काढणे)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bank_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    bank_account_id UUID NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    type TEXT NOT NULL, -- 'deposit', 'withdrawal', 'interest', 'charge'
    amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
    deposit_slip_or_cheque_no TEXT,
    transaction_number TEXT,
    purpose TEXT,
    performed_by TEXT,
    approved_by TEXT,
    balance_after NUMERIC(14, 2) DEFAULT 0.00,
    remarks TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure balance_after has a safe default and is not strictly required
ALTER TABLE public.bank_transactions ALTER COLUMN balance_after DROP NOT NULL;
ALTER TABLE public.bank_transactions ALTER COLUMN balance_after SET DEFAULT 0.00;
ALTER TABLE public.bank_transactions ADD COLUMN IF NOT EXISTS performed_by TEXT;
ALTER TABLE public.bank_transactions ADD COLUMN IF NOT EXISTS transaction_number TEXT;
ALTER TABLE public.bank_transactions ADD COLUMN IF NOT EXISTS deposit_slip_or_cheque_no TEXT;

CREATE INDEX IF NOT EXISTS idx_bank_tx_group_date ON public.bank_transactions (group_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_bank_tx_account ON public.bank_transactions (bank_account_id);

-- ------------------------------------------------------------------------------
-- 3. TABLE: saving_plans (बचत योजना सेटिंग्ज)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.saving_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    plan_name TEXT NOT NULL DEFAULT 'Regular Monthly Saving',
    monthly_amount NUMERIC(12, 2) NOT NULL DEFAULT 500.00,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE,
    due_day INTEGER NOT NULL DEFAULT 10,
    grace_period_days INTEGER NOT NULL DEFAULT 5,
    late_fee NUMERIC(10, 2) NOT NULL DEFAULT 20.00,
    status TEXT NOT NULL DEFAULT 'active',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_saving_plans_group ON public.saving_plans (group_id);

-- ------------------------------------------------------------------------------
-- 4. TABLE: monthly_savings (मासिक सभासद बचत नोंदी)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.monthly_savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    saving_plan_id UUID REFERENCES public.saving_plans(id) ON DELETE SET NULL,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INTEGER NOT NULL CHECK (year >= 2020),
    due_date DATE NOT NULL,
    expected_amount NUMERIC(12, 2) NOT NULL DEFAULT 500.00,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    late_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    balance_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_mode TEXT NOT NULL DEFAULT 'cash',
    transaction_id TEXT,
    receipt_number TEXT,
    payment_date DATE,
    collected_by TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    remarks TEXT,
    bank_account_id UUID REFERENCES public.bank_accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_member_month_year UNIQUE (group_id, member_id, month, year)
);

ALTER TABLE public.monthly_savings ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES public.bank_accounts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_monthly_savings_group_month_year ON public.monthly_savings (group_id, year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_savings_member ON public.monthly_savings (member_id);
CREATE INDEX IF NOT EXISTS idx_monthly_savings_status ON public.monthly_savings (status);

-- ------------------------------------------------------------------------------
-- 5. CROSS-MODULE BANK COLUMN ADDITIONS (कर्ज, हप्ते, जमा व खर्च मध्ये बँक ट्रॅकिंग)
-- ------------------------------------------------------------------------------
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES public.bank_accounts(id) ON DELETE SET NULL;
ALTER TABLE public.loan_emis ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES public.bank_accounts(id) ON DELETE SET NULL;
ALTER TABLE public.incomes ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES public.bank_accounts(id) ON DELETE SET NULL;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES public.bank_accounts(id) ON DELETE SET NULL;

-- ------------------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (RLS) POLICIES & PERMISSIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saving_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_savings ENABLE ROW LEVEL SECURITY;

-- Allow full access for anon and authenticated users
DROP POLICY IF EXISTS Allow full access on bank_accounts ON public.bank_accounts;
CREATE POLICY Allow full access on bank_accounts ON public.bank_accounts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS Allow full access on bank_transactions ON public.bank_transactions;
CREATE POLICY Allow full access on bank_transactions ON public.bank_transactions FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS Allow full access on saving_plans ON public.saving_plans;
CREATE POLICY Allow full access on saving_plans ON public.saving_plans FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS Allow full access on monthly_savings ON public.monthly_savings;
CREATE POLICY Allow full access on monthly_savings ON public.monthly_savings FOR ALL USING (true) WITH CHECK (true);

-- Grant privileges to anon, authenticated, and service_role
GRANT ALL ON public.bank_accounts TO anon, authenticated, service_role;
GRANT ALL ON public.bank_transactions TO anon, authenticated, service_role;
GRANT ALL ON public.saving_plans TO anon, authenticated, service_role;
GRANT ALL ON public.monthly_savings TO anon, authenticated, service_role;
