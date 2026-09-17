-- ==============================================================================
-- MIGRATION: Add bank_loans and saving_plans tables to public schema
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/ifhwminbybeypntvmscf/sql/new
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.bank_loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    bank_name VARCHAR(150) NOT NULL,
    account_number VARCHAR(50),
    loan_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    tenure_months INT DEFAULT 24,
    interest_rate NUMERIC(5, 2) DEFAULT 7.00,
    status VARCHAR(30) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.saving_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    plan_name VARCHAR(100) NOT NULL,
    monthly_amount NUMERIC(10, 2) NOT NULL DEFAULT 200.00,
    interest_rate NUMERIC(5, 2) DEFAULT 0.00,
    due_day INT DEFAULT 10,
    late_fee NUMERIC(8, 2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Grant access to application roles
GRANT ALL ON public.bank_loans TO anon, authenticated, service_role;
GRANT ALL ON public.saving_plans TO anon, authenticated, service_role;
