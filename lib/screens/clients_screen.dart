import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import 'add_client_screen.dart';
import 'client_bills_screen.dart';

class ClientsScreen extends StatefulWidget {
  final AppUser appUser;
  const ClientsScreen({super.key, required this.appUser});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> clients = [];
  bool isLoading = true;
  String? loadError;

  bool get isManager => widget.appUser.isManager;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final list = await FirestoreService.instance.getClients();
      if (!mounted) return;
      setState(() {
        clients = list;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = 'تعذر تحميل قائمة العملاء: $e';
      });
    }
  }

  Future<void> _confirmDeleteClient(Client c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العميل'),
        content: Text(
          'سيتم حذف "${c.name}" وكل ما يخصه من بوالص وفواتير ومستندات ومدفوعات نهائياً. '
          'هذا الإجراء لا يمكن التراجع عنه. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائياً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirestoreService.instance.deleteClient(c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف "${c.name}" بنجاح')));
      _loadClients();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف العميل: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة العملاء'),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF003366),
              child: const Icon(Icons.person_add, color: Colors.white),
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddClientScreen()),
                );
                if (res == true) _loadClients();
              },
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadClients, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              : clients.isEmpty
                  ? const Center(child: Text('لا يوجد عملاء مضافين حالياً. اضغط + لإضافة عميل جديد.'))
                  : ListView.builder(
                      itemCount: clients.length,
                      itemBuilder: (context, index) {
                        final c = clients[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF0099CC),
                              child: Icon(Icons.folder_shared, color: Colors.white),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('هاتف: ${c.phone} | الرقم الضريبي: ${c.taxNumber}'),
                            trailing: isManager
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: 'حذف العميل',
                                        onPressed: () => _confirmDeleteClient(c),
                                      ),
                                      const Icon(Icons.chevron_left),
                                    ],
                                  )
                                : const Icon(Icons.chevron_left),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ClientBillsScreen(client: c, appUser: widget.appUser)),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
