import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/pending_document.dart';
import '../models/shipment_document.dart';
import '../services/firestore_service.dart';

class PendingReviewScreen extends StatefulWidget {
  final AppUser appUser;
  const PendingReviewScreen({super.key, required this.appUser});

  @override
  State<PendingReviewScreen> createState() => _PendingReviewScreenState();
}

class _PendingReviewScreenState extends State<PendingReviewScreen> {
  bool isLoading = true;
  List<PendingDocument> pending = [];
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final list = await FirestoreService.instance.getPendingDocuments();
    if (!mounted) return;
    setState(() {
      pending = list;
      isLoading = false;
    });
  }

  Future<void> _approve(PendingDocument pd) async {
    setState(() => _busyIds.add(pd.id));
    try {
      await FirestoreService.instance.approvePendingDocument(pd, reviewerName: widget.appUser.name);
      if (!mounted) return;
      setState(() => pending.removeWhere((p) => p.id == pd.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاعتماد وحفظه في ملف العميل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الاعتماد: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(pd.id));
    }
  }

  Future<void> _reject(PendingDocument pd) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض المستند'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'سبب الرفض (اختياري)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(pd.id));
    try {
      await FirestoreService.instance.rejectPendingDocument(pd, reviewerName: widget.appUser.name, reason: reasonCtrl.text.trim());
      if (!mounted) return;
      setState(() => pending.removeWhere((p) => p.id == pd.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض المستند')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(pd.id));
    }
  }

  void _viewImages(PendingDocument pd) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 400,
          child: Stack(
            children: [
              PageView(
                children: pd.imageUrls
                    .map((url) => InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, size: 64)),
                          ),
                        ))
                    .toList(),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الطلبات المعلقة')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pending.isEmpty
              ? const Center(child: Text('لا توجد طلبات بانتظار المراجعة حالياً.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: pending.length,
                    itemBuilder: (context, index) {
                      final pd = pending[index];
                      final busy = _busyIds.contains(pd.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Chip(
                                    label: Text(DocType.shortTitle(pd.docType)),
                                    backgroundColor: const Color(0xFF0099CC),
                                    labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  const Spacer(),
                                  Text(pd.date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('العميل: ${pd.clientNameInput}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('رقم البوليصة: ${pd.billNumber}'),
                              Text('رفعه: ${pd.uploadedByName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              ...pd.items.map((it) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(it.description)),
                                        Text('${it.amount.toStringAsFixed(2)} SDG'),
                                      ],
                                    ),
                                  )),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('الإجمالي: ${pd.totalAmount.toStringAsFixed(2)} SDG',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (pd.imageUrls.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () => _viewImages(pd),
                                      icon: const Icon(Icons.image, size: 18),
                                      label: Text('عرض الصور (${pd.imageUrls.length})'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (busy)
                                const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        onPressed: () => _reject(pd),
                                        icon: const Icon(Icons.close),
                                        label: const Text('رفض'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        onPressed: () => _approve(pd),
                                        icon: const Icon(Icons.check, color: Colors.white),
                                        label: const Text('اعتماد', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
