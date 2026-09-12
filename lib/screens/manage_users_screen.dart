import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/shipment_document.dart';
import '../services/auth_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool isLoading = true;
  List<AppUser> users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final list = await AuthService.instance.getAllUsers();
    if (!mounted) return;
    setState(() {
      users = list;
      isLoading = false;
    });
  }

  Future<void> _toggleActive(AppUser u) async {
    await AuthService.instance.setUserActive(u.uid, !u.active);
    _load();
  }

  Future<void> _editPermissions(AppUser u) async {
    final perms = Map<String, bool>.from(u.permissions);
    for (final t in DocType.all) {
      perms.putIfAbsent(t, () => false);
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('صلاحيات ${u.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: DocType.all
                .map((t) => CheckboxListTile(
                      value: perms[t],
                      title: Text(DocType.shortTitle(t)),
                      onChanged: (v) => setDialogState(() => perms[t] = v ?? false),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved == true) {
      await AuthService.instance.updateUserPermissions(u.uid, perms);
      _load();
    }
  }

  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final perms = {for (final t in DocType.all) t: false};
    String? error;
    bool creating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة يوزر جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم (بدون مسافات)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور (6 أحرف على الأقل)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('الصلاحيات (الأقسام المسموح رفع مستندات فيها):', style: Theme.of(ctx).textTheme.bodySmall),
                ),
                ...DocType.all.map((t) => CheckboxListTile(
                      dense: true,
                      value: perms[t],
                      title: Text(DocType.shortTitle(t)),
                      onChanged: (v) => setDialogState(() => perms[t] = v ?? false),
                    )),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: creating ? null : () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: creating
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().length < 6) {
                        setDialogState(() => error = 'تأكد من ملء الاسم واسم المستخدم وكلمة مرور من 6 أحرف على الأقل');
                        return;
                      }
                      setDialogState(() {
                        creating = true;
                        error = null;
                      });
                      final result = await AuthService.instance.createEmployeeAccount(
                        name: nameCtrl.text.trim(),
                        username: userCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                        permissions: perms,
                      );
                      if (result != null) {
                        setDialogState(() {
                          creating = false;
                          error = result;
                        });
                        return;
                      }
                      if (context.mounted) Navigator.pop(ctx);
                    },
              child: creating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إنشاء الحساب'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF003366),
        onPressed: _addUser,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('إضافة يوزر جديد', style: TextStyle(color: Colors.white)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                final allowedSections = DocType.all.where((t) => u.permissions[t] == true).map(DocType.shortTitle).join('، ');
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.isManager ? Colors.orange.shade800 : const Color(0xFF0099CC),
                      child: Icon(u.isManager ? Icons.admin_panel_settings : Icons.person, color: Colors.white),
                    ),
                    title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      u.isManager
                          ? 'مدير - يوزر: ${u.username}'
                          : 'يوزر: ${u.username}\nالصلاحيات: ${allowedSections.isEmpty ? 'لا توجد' : allowedSections}',
                    ),
                    isThreeLine: !u.isManager,
                    trailing: u.isManager
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'perms') _editPermissions(u);
                              if (v == 'toggle') _toggleActive(u);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'perms', child: Text('تعديل الصلاحيات')),
                              PopupMenuItem(value: 'toggle', child: Text(u.active ? 'إيقاف الحساب' : 'تفعيل الحساب')),
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }
}
