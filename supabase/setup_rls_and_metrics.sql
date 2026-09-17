-- ==============================================================================
-- SAKHI BACHAT GAT - SUPABASE PERMISSIONS, RLS POLICIES & DASHBOARD METRICS
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/ifhwminbybeypntvmscf/sql/new
-- ==============================================================================

-- 1. Grant Schema & Table Permissions to 'anon' and 'authenticated' (Needed for Flutter App)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

-- 2. Helper function to extract user's group_id from profiles
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

-- 3. Dashboard Metrics RPC Function
CREATE OR REPLACE FUNCTION public.get_dashboard_metrics(p_group_id UUID)
RETURNS JSON AS $$
DECLARE
    v_total_members INT := 0;
    v_total_savings NUMERIC := 0;
    v_active_loans NUMERIC := 0;
    v_pending_emis INT := 0;
    v_bank_balance NUMERIC := 0;
    v_cash_in_hand NUMERIC := 0;
    v_total_income NUMERIC := 0;
    v_total_expenses NUMERIC := 0;
    v_total_profit NUMERIC := 0;
BEGIN
    SELECT COUNT(*) INTO v_total_members FROM public.members WHERE group_id = p_group_id AND status = 'active';
    SELECT COALESCE(SUM(amount), 0) INTO v_total_savings FROM public.savings WHERE group_id = p_group_id;
    SELECT COALESCE(SUM(outstanding_principal), 0) INTO v_active_loans FROM public.loans WHERE group_id = p_group_id AND status = 'disbursed';
    SELECT COUNT(*) INTO v_pending_emis FROM public.loan_emis WHERE group_id = p_group_id AND status = 'pending';
    SELECT COALESCE(SUM(current_balance), 0) INTO v_bank_balance FROM public.bank_accounts WHERE group_id = p_group_id;
    SELECT COALESCE(balance_after, 0) INTO v_cash_in_hand FROM public.cash_book WHERE group_id = p_group_id ORDER BY created_at DESC LIMIT 1;
    SELECT COALESCE(SUM(amount), 0) INTO v_total_income FROM public.incomes WHERE group_id = p_group_id;
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses FROM public.expenses WHERE group_id = p_group_id;
    v_total_profit := GREATEST(0, (COALESCE(v_total_income, 0) - COALESCE(v_total_expenses, 0)));

    RETURN json_build_object(
        'total_members', COALESCE(v_total_members, 0),
        'total_savings', COALESCE(v_total_savings, 0),
        'active_loans', COALESCE(v_active_loans, 0),
        'pending_emis', COALESCE(v_pending_emis, 0),
        'bank_balance', COALESCE(v_bank_balance, 0),
        'cash_in_hand', COALESCE(v_cash_in_hand, 0),
        'total_income', COALESCE(v_total_income, 0),
        'total_expenses', COALESCE(v_total_expenses, 0),
        'total_profit', COALESCE(v_total_profit, 0)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Enable Row Level Security & Create Accessible Policies Dynamically on ALL Existing Tables
DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP 
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);
        EXECUTE format('DROP POLICY IF EXISTS "allow_app_access_%I" ON public.%I;', r.tablename, r.tablename);
        EXECUTE format('CREATE POLICY "allow_app_access_%I" ON public.%I FOR ALL TO anon, authenticated, service_role USING (true) WITH CHECK (true);', r.tablename, r.tablename);
    END LOOP; 
END $$;
