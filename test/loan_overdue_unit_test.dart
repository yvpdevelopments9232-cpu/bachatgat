import 'package:flutter_test/flutter_test.dart';
import 'package:sakhi_bachat_gat/models/loan.dart';

void main() {
  group('calculateLoanOverdue Tests', () {
    final sampleLoan = Loan(
      id: 'loan-123',
      groupId: 'g-001',
      memberId: 'm-001',
      memberName: '?????? ????',
      loanCode: 'LN-2026-001',
      applicationDate: '2026-01-01',
      requestedAmount: 20000,
      approvedAmount: 20000,
      interestRate: 12.0,
      loanPeriodMonths: 12,
      emiAmount: 1500.0,
      numberOfEmis: 12,
      firstEmiDate: '2026-01-01',
      outstandingPrincipal: 18333.0,
      totalRepaid: 1500.0,
      status: 'disbursed',
    );

    test('EMI 1 paid on 2026-01-01, EMI 2 due on 2026-02-01: On 2026-01-15 not overdue', () {
      final emis = [
        LoanEmi(
          id: 'emi-1',
          loanId: sampleLoan.id,
          emiNumber: 1,
          dueDate: '2026-01-01',
          principal: 1400,
          interest: 100,
          emiAmount: 1500,
          paidAmount: 1500,
          status: 'paid',
        ),
      ];

      final info = calculateLoanOverdue(sampleLoan, emis, DateTime(2026, 1, 15));
      expect(info.isOverdue, false);
      expect(info.overdueMonths, 0);
      expect(info.overdueAmount, 0.0);
      expect(info.totalOutstanding, 18333.0);
      expect(info.totalPaidEmis, 1);
    });

    test('User test case: EMI 1 paid on 2026-01-01, on 2026-03-05 2 months overdue = Rs 3000', () {
      final emis = [
        LoanEmi(
          id: 'emi-1',
          loanId: sampleLoan.id,
          emiNumber: 1,
          dueDate: '2026-01-01',
          principal: 1400,
          interest: 100,
          emiAmount: 1500,
          paidAmount: 1500,
          status: 'paid',
        ),
      ];

      // As of 2026-03-05:
      // EMI 2 (due 2026-02-01) is overdue (1500)
      // EMI 3 (due 2026-03-01) is overdue (1500)
      // Total overdue amount must be 3000, NOT 18333!
      final info = calculateLoanOverdue(sampleLoan, emis, DateTime(2026, 3, 5));
      expect(info.isOverdue, true);
      expect(info.overdueMonths, 2);
      expect(info.overdueAmount, 3000.0);
      expect(info.totalOutstanding, 18333.0);
    });

    test('Partial payment on overdue EMI reduces overdueAmount accurately', () {
      final emis = [
        LoanEmi(
          id: 'emi-1',
          loanId: sampleLoan.id,
          emiNumber: 1,
          dueDate: '2026-01-01',
          principal: 1400,
          interest: 100,
          emiAmount: 1500,
          paidAmount: 1500,
          status: 'paid',
        ),
        LoanEmi(
          id: 'emi-2',
          loanId: sampleLoan.id,
          emiNumber: 2,
          dueDate: '2026-02-01',
          principal: 1400,
          interest: 100,
          emiAmount: 1500,
          paidAmount: 500,
          status: 'partial',
        ),
      ];

      final info = calculateLoanOverdue(sampleLoan, emis, DateTime(2026, 2, 15));
      expect(info.isOverdue, true);
      expect(info.overdueMonths, 1);
      expect(info.overdueAmount, 1000.0);
    });

    test('All EMIs paid: isOverdue is false, overdueAmount is 0', () {
      final emis = List.generate(12, (index) {
        final num = index + 1;
        return LoanEmi(
          id: 'emi-$num',
          loanId: sampleLoan.id,
          emiNumber: num,
          dueDate: '2026-0$num-01',
          principal: 1400,
          interest: 100,
          emiAmount: 1500,
          paidAmount: 1500,
          status: 'paid',
        );
      });

      final info = calculateLoanOverdue(sampleLoan, emis, DateTime(2027, 5, 1));
      expect(info.isOverdue, false);
      expect(info.overdueMonths, 0);
      expect(info.overdueAmount, 0.0);
      expect(info.totalPaidEmis, 12);
    });
  });

  group('Fixed vs Decreasing EMI Calculation Tests', () {
    test('Fixed EMI standard reducing balance test (50,000 @ 12% 12 months = 4,442)', () {
      final emi = calculateFixedEmi(principal: 50000, annualRate: 12, months: 12);
      expect(emi.round(), 4442);
    });

    test('Decreasing EMI monthly progression test (50,000 @ 12% 12 months)', () {
      final m1 = calculateDecreasingEmi(principal: 50000, annualRate: 12, months: 12, monthIndex: 1);
      final m2 = calculateDecreasingEmi(principal: 50000, annualRate: 12, months: 12, monthIndex: 2);
      final m3 = calculateDecreasingEmi(principal: 50000, annualRate: 12, months: 12, monthIndex: 3);
      final m12 = calculateDecreasingEmi(principal: 50000, annualRate: 12, months: 12, monthIndex: 12);

      expect(m1.round(), 4667);
      expect(m2.round(), 4625);
      expect(m3.round(), 4583);
      expect(m12.round(), 4208);
    });

    test('Loan model isFixedEmi and isDecreasingEmi getters', () {
      final fixedLoan = Loan(
        id: '1',
        groupId: 'g1',
        memberId: 'm1',
        loanCode: 'L001',
        applicationDate: '2026-01-01',
        interestType: 'fixed',
        requestedAmount: 50000,
        approvedAmount: 50000,
        interestRate: 12,
        loanPeriodMonths: 12,
        emiAmount: 4442,
        numberOfEmis: 12,
        firstEmiDate: '2026-02-01',
        status: 'active',
      );

      final decLoan = Loan(
        id: '2',
        groupId: 'g1',
        memberId: 'm2',
        loanCode: 'L002',
        applicationDate: '2026-01-01',
        interestType: 'decreasing',
        requestedAmount: 50000,
        approvedAmount: 50000,
        interestRate: 12,
        loanPeriodMonths: 12,
        emiAmount: 4667,
        numberOfEmis: 12,
        firstEmiDate: '2026-02-01',
        status: 'active',
      );

      expect(fixedLoan.isFixedEmi, true);
      expect(fixedLoan.isDecreasingEmi, false);
      expect(decLoan.isDecreasingEmi, true);
      expect(decLoan.isFixedEmi, false);
    });
  });
}
