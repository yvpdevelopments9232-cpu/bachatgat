-- ==============================================================================
-- SAKHI BACHAT GAT - MULTI-TENANT ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
-- This script enables strict PostgreSQL Row Level Security (RLS) on all tables.
-- Bachat Gat A (group_id = A) can NEVER view or modify Bachat Gat B (group_id = B) data.
-- ==============================================================================

-- 1. Helper function to extract user's group_id from profiles
CREATE OR REPLACE FUNCTION public.get_auth_group_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT group_id 
        FROM public.profiles 
        WHERE id = auth.uid()
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 2. Enable RLS on all Tenant-Scoped Tables
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_emis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_book ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for Groups (Users can view their own Bachat Gat)
DROP POLICY IF EXISTS "tenant_groups_policy" ON public.groups;
CREATE POLICY "tenant_groups_policy" ON public.groups
    FOR ALL
    USING (id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 4. RLS Policies for Profiles
DROP POLICY IF EXISTS "tenant_profiles_policy" ON public.profiles;
CREATE POLICY "tenant_profiles_policy" ON public.profiles
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 5. RLS Policies for Members
DROP POLICY IF EXISTS "tenant_members_policy" ON public.members;
CREATE POLICY "tenant_members_policy" ON public.members
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 6. RLS Policies for Savings
DROP POLICY IF EXISTS "tenant_savings_policy" ON public.savings;
CREATE POLICY "tenant_savings_policy" ON public.savings
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 7. RLS Policies for Loans & EMIs
DROP POLICY IF EXISTS "tenant_loans_policy" ON public.loans;
CREATE POLICY "tenant_loans_policy" ON public.loans
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "tenant_emis_policy" ON public.loan_emis;
CREATE POLICY "tenant_emis_policy" ON public.loan_emis
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 8. RLS Policies for Meetings & Attendance
DROP POLICY IF EXISTS "tenant_meetings_policy" ON public.meetings;
CREATE POLICY "tenant_meetings_policy" ON public.meetings
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 9. RLS Policies for Finance (Incomes, Expenses, Cash Book, Bank Accounts)
DROP POLICY IF EXISTS "tenant_incomes_policy" ON public.incomes;
CREATE POLICY "tenant_incomes_policy" ON public.incomes
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "tenant_expenses_policy" ON public.expenses;
CREATE POLICY "tenant_expenses_policy" ON public.expenses
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "tenant_bank_policy" ON public.bank_accounts;
CREATE POLICY "tenant_bank_policy" ON public.bank_accounts
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "tenant_cash_policy" ON public.cash_book;
CREATE POLICY "tenant_cash_policy" ON public.cash_book
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 10. RLS Policies for Inventory & Sales
DROP POLICY IF EXISTS "tenant_products_policy" ON public.products;
CREATE POLICY "tenant_products_policy" ON public.products
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "tenant_sales_policy" ON public.sales;
CREATE POLICY "tenant_sales_policy" ON public.sales
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

-- 11. RLS Policies for Central Dues & Notifications
DROP POLICY IF EXISTS "tenant_dues_policy" ON public.dues;
CREATE POLICY "tenant_dues_policy" ON public.dues
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "tenant_notifications_policy" ON public.notifications;
CREATE POLICY "tenant_notifications_policy" ON public.notifications
    FOR ALL
    USING (group_id = public.get_auth_group_id() OR auth.role() = 'service_role')
    WITH CHECK (group_id = public.get_auth_group_id() OR auth.role() = 'service_role');
