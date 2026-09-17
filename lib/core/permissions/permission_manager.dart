class PermissionManager {
  static bool hasPermission({
    required String role,
    required String module,
    required String action,
    Map<String, dynamic>? customPermissions,
  }) {
    if (role == 'admin') return true;

    // Default Role capabilities
    if (role == 'president' || role == 'secretary') {
      if (action == 'delete' && module == 'users') return false;
      return true;
    }

    if (role == 'treasurer') {
      if (['savings', 'loans', 'bank_cash', 'income', 'expenses', 'dues'].contains(module)) {
        if (action == 'delete' || action == 'approve') return false;
        return true;
      }
      if (action == 'view') return true;
      return false;
    }

    if (role == 'employee') {
      if (action == 'view') return true;
      if (['savings', 'stock'].contains(module) && action == 'add') return true;
      return false;
    }

    return false;
  }
}
