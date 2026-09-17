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
