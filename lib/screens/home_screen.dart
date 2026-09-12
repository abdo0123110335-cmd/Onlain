import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/shipment_document.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'clients_screen.dart';
import 'scan_ocr_screen.dart';
import 'pending_review_screen.dart';
import 'manage_users_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppUser appUser;
  const HomeScreen({super.key, required this.appUser});

  @override
  Widget build(BuildContext context) {
    final isManager = appUser.isManager;
    // الأقسام المسموح لهذا المستخدم برفع مستندات فيها.
    final visibleDocTypes = DocType.all.where((t) => appUser.canUpload(t)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أعمال الشيخ مختار للتخليص الجمركي'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة الترحيب والهيدر
            Card(
              color: const Color(0xFF003366),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.directions_boat, size: 50, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      'مرحباً ${appUser.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isManager ? 'مدير النظام' : 'موظف',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (visibleDocTypes.isNotEmpty) ...[
              const Text(
                'الخدمات السريعة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003366)),
              ),
              const SizedBox(height: 10),
              _buildDocTypeGrid(context, visibleDocTypes),
              const SizedBox(height: 20),
            ] else if (!isManager) ...[
              Card(
                color: Colors.amber.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'ليس لديك صلاحية رفع مستندات في أي قسم بعد. تواصل مع المدير لتفعيل الصلاحية المناسبة لك.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (!isManager) ...[
              _buildActionButton(
                context,
                title: 'عرض المستندات وتنزيلها',
                icon: Icons.folder_open,
                color: Colors.indigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ClientsScreen(appUser: appUser)),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (isManager) ...[
              const Text(
                'إدارة النظام (المدير فقط)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003366)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context,
                      title: 'قسم الفواتير',
                      icon: Icons.folder_special,
                      color: Colors.orange.shade800,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ClientsScreen(appUser: appUser)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: FirestoreService.instance.streamPendingCount(),
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        return _buildActionButton(
                          context,
                          title: 'مراجعة الطلبات المعلقة',
                          icon: Icons.pending_actions,
                          color: count > 0 ? Colors.red.shade700 : Colors.blueGrey,
                          badge: count > 0 ? count.toString() : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PendingReviewScreen(appUser: appUser)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                title: 'إدارة المستخدمين وإضافة يوزر جديد',
                icon: Icons.admin_panel_settings,
                color: Colors.teal.shade800,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocTypeGrid(BuildContext context, List<String> types) {
    final colors = {
      DocType.ports: const Color(0xFF0099CC),
      DocType.customs: const Color(0xFF003366),
      DocType.storage: Colors.deepPurple,
      DocType.permit: Colors.brown,
      DocType.quality: Colors.green.shade800,
    };
    final icons = {
      DocType.ports: Icons.receipt_long,
      DocType.customs: Icons.document_scanner,
      DocType.storage: Icons.warehouse,
      DocType.permit: Icons.fact_check,
      DocType.quality: Icons.verified_outlined,
    };
    final titles = {
      DocType.ports: 'فاتورة رسوم موانئ',
      DocType.customs: 'فاتورة إشعار أسيكودا',
      DocType.storage: 'فاتورة أرضيات الشركة',
      DocType.permit: 'رسوم إذن الشركة',
      DocType.quality: 'فاتورة رسوم الجودة',
    };

    final rows = <Widget>[];
    for (var i = 0; i < types.length; i += 2) {
      final rowTypes = types.skip(i).take(2).toList();
      rows.add(Row(
        children: [
          for (final t in rowTypes) ...[
            Expanded(
              child: _buildActionButton(
                context,
                title: titles[t] ?? DocType.shortTitle(t),
                icon: icons[t] ?? Icons.description,
                color: colors[t] ?? Colors.blueGrey,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ScanOCRScreen(docType: t, appUser: appUser)),
                ),
              ),
            ),
            if (rowTypes.length > 1 && t != rowTypes.last) const SizedBox(width: 12),
          ],
          if (rowTypes.length == 1) const Expanded(child: SizedBox()),
        ],
      ));
      rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Icon(icon, size: 36, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -8,
                right: -8,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.white,
                  child: Text(badge, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
