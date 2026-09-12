import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/bill_of_lading.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import 'invoice_detail_screen.dart';

/// يعرض كل بوالص الشحن (البوالص) الخاصة بعميل واحد. الضغط على بوليصة يفتح
/// فاتورتها الموحّدة مع كل المستندات والرسوم والدفعات المرتبطة بها.
class ClientBillsScreen extends StatefulWidget {
  final Client client;
  final AppUser appUser;
  const ClientBillsScreen({super.key, required this.client, required this.appUser});

  @override
  State<ClientBillsScreen> createState() => _ClientBillsScreenState();
}

class _ClientBillsScreenState extends State<ClientBillsScreen> {
  bool isLoading = true;
  String? loadError;
  List<BillOfLading> bills = [];

  bool get isManager => widget.appUser.isManager;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final list = await FirestoreService.instance.getBillOfLadingsForClient(widget.client.id);
      if (!mounted) return;
      setState(() {
        bills = list;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = 'تعذر تحميل بوالص هذا العميل: $e';
      });
    }
  }

  Future<void> _confirmDeleteBill(BillOfLading bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف البوليصة'),
        content: Text(
          'سيتم حذف بوليصة رقم "${bill.billNumber}" وكل ما يخصها من مستندات وفاتورة ومدفوعات نهائياً. '
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
      await FirestoreService.instance.deleteBillOfLading(bill.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف بوليصة "${bill.billNumber}" بنجاح')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف البوليصة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ملف العميل: ${widget.client.name}')),
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
                        ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              : bills.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'لا توجد بوالص مسجلة لهذا العميل بعد.\nستظهر هنا كل بوليصة بعد تصوير أول مستند لها.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF003366),
                            child: Icon(Icons.folder, color: Colors.white),
                          ),
                          title: Text('بوليصة رقم: ${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            [
                              if (bill.vesselName.isNotEmpty) bill.vesselName,
                              if (bill.containerCount > 0) '${bill.containerCount} حاوية',
                              bill.date,
                            ].join(' • '),
                          ),
                          trailing: isManager
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'حذف البوليصة',
                                      onPressed: () => _confirmDeleteBill(bill),
                                    ),
                                    const Icon(Icons.chevron_left),
                                  ],
                                )
                              : const Icon(Icons.chevron_left),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailScreen(billOfLadingId: bill.id, appUser: widget.appUser),
                              ),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
