import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/data/office_mailto.dart';

List<String> officeRecipientEmails() {
  final emails = <String>{
    for (final email in officeEmails) email.trim().toLowerCase(),
  };
  for (final user in StaffStore.instance.employees) {
    if (!user.active) continue;
    if (user.role != 'admin' && user.role != 'ambos') continue;
    final email = user.email.trim().toLowerCase();
    if (isMailAddress(email)) emails.add(email);
  }
  emails.removeWhere((email) => !isMailAddress(email));
  return emails.toList();
}

String officeRecipientTo() => officeRecipientEmails().join(', ');
