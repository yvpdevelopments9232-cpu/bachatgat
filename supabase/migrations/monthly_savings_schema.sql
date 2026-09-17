-- =============================================================================
-- SAKHI BACHAT GAT - MONTHLY SAVINGS & SAVING PLANS SCHEMA
-- =============================================================================

-- 1. SAVING PLANS TABLE (बचत योजना सेटिंग्ज)
CREATE TABLE IF NOT EXISTS public.saving_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    plan_name TEXT NOT NULL DEFAULT 'Regular Monthly Saving',
    monthly_amount NUMERIC NOT NULL DEFAULT 500.0,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE,
    due_day INTEGER NOT NULL DEFAULT 10, -- 10th of every month
    grace_period_days INTEGER NOT NULL DEFAULT 5, -- 5 days grace period
    late_fee NUMERIC NOT NULL DEFAULT 20.0, -- Rs 20 late fee
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. MONTHLY SAVINGS TABLE (प्रत्येक महिन्याची स्वतंत्र बचत नोंद)
CREATE TABLE IF NOT EXISTS public.monthly_savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
    saving_plan_id UUID REFERENCES public.saving_plans(id) ON DELETE SET NULL,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INTEGER NOT NULL CHECK (year >= 2020),
    due_date DATE NOT NULL,
    expected_amount NUMERIC NOT NULL DEFAULT 500.0,
    paid_amount NUMERIC NOT NULL DEFAULT 0.0,
    late_fee NUMERIC NOT NULL DEFAULT 0.0,
    balance_amount NUMERIC NOT NULL DEFAULT 0.0,
    payment_mode TEXT NOT NULL DEFAULT 'cash' CHECK (payment_mode IN ('cash', 'upi', 'bank', 'other')),
    transaction_id TEXT,
    receipt_number TEXT,
    payment_date DATE,
    collected_by TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('paid', 'partial', 'pending', 'overdue')),
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_member_month_year UNIQUE (group_id, member_id, month, year)
);

-- 3. INDEXES FOR HIGH PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_monthly_savings_group_month_year ON public.monthly_savings (group_id, year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_savings_member ON public.monthly_savings (member_id);
CREATE INDEX IF NOT EXISTS idx_monthly_savings_status ON public.monthly_savings (status);
CREATE INDEX IF NOT EXISTS idx_saving_plans_group ON public.saving_plans (group_id);

-- 4. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.saving_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_savings ENABLE ROW LEVEL SECURITY;

-- 5. RLS POLICIES (Allow full access for authenticated and anon users)
DROP POLICY IF EXISTS "Allow full access on saving_plans" ON public.saving_plans;
CREATE POLICY "Allow full access on saving_plans" ON public.saving_plans
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow full access on monthly_savings" ON public.monthly_savings;
CREATE POLICY "Allow full access on monthly_savings" ON public.monthly_savings
    FOR ALL USING (true) WITH CHECK (true);

-- 6. INSERT DEFAULT SAVING PLAN FOR EXISTING GROUPS
INSERT INTO public.saving_plans (group_id, plan_name, monthly_amount, due_day, grace_period_days, late_fee, status)
SELECT id, 'Regular Monthly Saving (नियमित मासिक बचत)', COALESCE(monthly_savings_amount, 500.0), 10, 5, 20.0, 'active'
FROM public.groups
ON CONFLICT DO NOTHING;
