import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/clearance_invoice.dart';
import '../models/client.dart';
import '../models/bill_of_lading.dart';
import '../models/shipment_document.dart';
import '../models/app_user.dart';
import '../models/pending_document.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/ocr_service.dart';
import 'invoice_detail_screen.dart';

/// صف بند واحد (اسم البند + مبلغه) مع الـ controllers الخاصة به.
class _ItemRow {
  final TextEditingController descCtrl;
  final TextEditingController amountCtrl;
  _ItemRow({String desc = '', String amount = ''})
      : descCtrl = TextEditingController(text: desc),
        amountCtrl = TextEditingController(text: amount);

  void dispose() {
    descCtrl.dispose();
    amountCtrl.dispose();
  }
}

/// شاشة إدخال بيانات المستند بعد تصويره/رفعه: تطلب فقط (رقم البوليصة، اسم
/// العميل، المبلغ) كحد أدنى، مع إمكانية فتح "بيانات إضافية" اختيارية.
///
/// - إن كان المستخدم مديراً: يُحفظ المستند مباشرة داخل ملف العميل وقسم الفواتير.
/// - إن كان موظفاً: يُرسل المستند إلى قائمة "الطلبات المعلّقة" بانتظار مراجعة
///   واعتماد المدير، ولا يظهر في ملف العميل إلا بعد الموافقة عليه.
class ReviewInvoiceScreen extends StatefulWidget {
  final OCRResult ocrResult;
  final String docType;
  final List<File> imageFiles;
  final AppUser appUser;

  const ReviewInvoiceScreen({
    super.key,
    required this.ocrResult,
    required this.docType,
    required this.imageFiles,
    required this.appUser,
  });

  @override
  State<ReviewInvoiceScreen> createState() => _ReviewInvoiceScreenState();
}

class _ReviewInvoiceScreenState extends State<ReviewInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController clientNameCtrl;
  late TextEditingController billOfLadingCtrl;
  late TextEditingController declarationCtrl;
  late TextEditingController vesselCtrl;
  late TextEditingController containerCountCtrl;

  final List<_ItemRow> _items = [];
  String? _itemsError;
  bool _showAdvanced = false;

  List<Client> availableClients = [];
  Client? selectedClient;

  bool isSaving = false;

  bool get isManager => widget.appUser.isManager;

  @override
  void initState() {
    super.initState();
    clientNameCtrl = TextEditingController();
    billOfLadingCtrl = TextEditingController(text: widget.ocrResult.billNo);
    declarationCtrl = TextEditingController(text: widget.ocrResult.declarationNo);
    vesselCtrl = TextEditingController(text: widget.ocrResult.vesselName);
    containerCountCtrl = TextEditingController();

    if (widget.ocrResult.items.isNotEmpty) {
      widget.ocrResult.items.forEach((desc, amount) {
        _items.add(_ItemRow(desc: desc, amount: amount.toStringAsFixed(2)));
      });
    } else {
      _items.add(_ItemRow(
        desc: DocType.shortTitle(widget.docType),
        amount: widget.ocrResult.totalAmount > 0 ? widget.ocrResult.totalAmount.toStringAsFixed(2) : '',
      ));
    }

    _loadClients();
  }

  Future<void> _loadClients() async {
    final list = await FirestoreService.instance.getClients();
    if (!mounted) return;
    setState(() => availableClients = list);
  }

  void _addItemRow() => setState(() => _items.add(_ItemRow()));

  void _removeItemRow(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _itemsTotal {
    double total = 0;
    for (final item in _items) {
      total += double.tryParse(item.amountCtrl.text.trim()) ?? 0;
    }
    return total;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final validItems = _items
        .where((it) =>
            it.descCtrl.text.trim().isNotEmpty && (double.tryParse(it.amountCtrl.text.trim()) ?? 0) > 0)
        .toList();

    if (validItems.isEmpty) {
      setState(() => _itemsError = 'أدخل المبلغ (رقم أكبر من صفر) قبل الحفظ');
      return;
    }
    setState(() => _itemsError = null);
    setState(() => isSaving = true);

    try {
      if (isManager) {
        await _saveDirectly(validItems);
      } else {
        await _submitForReview(validItems);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')));
    }
  }

  // ---------------- مسار المدير: حفظ مباشر ----------------

  Future<void> _saveDirectly(List<_ItemRow> validItems) async {
    final now = DateFormat('yyyy/MM/dd').format(DateTime.now());
    final billNo = billOfLadingCtrl.text.trim();

    final client = selectedClient ??
        await FirestoreService.instance.findOrCreateClientByName(clientNameCtrl.text.trim(), createdByName: widget.appUser.name);

    final existingBol = await FirestoreService.instance.findBillOfLading(billNo, client.id);
    final containerCount = int.tryParse(containerCountCtrl.text.trim()) ?? existingBol?.containerCount ?? 0;
    final bolId = existingBol?.id ?? const Uuid().v4();
    final bol = BillOfLading(
      id: bolId,
      billNumber: billNo,
      clientId: client.id,
      clientName: client.name,
      vesselName: vesselCtrl.text.trim().isEmpty ? (existingBol?.vesselName ?? '') : vesselCtrl.text.trim(),
      containerCount: containerCount,
      date: existingBol?.date ?? now,
    );
    await FirestoreService.instance.insertBillOfLading(bol);

    final imageUrls = await StorageService.instance.uploadDocumentImages(
      files: widget.imageFiles,
      clientKey: client.id,
      billNumber: billNo,
    );
    for (var i = 0; i < imageUrls.length; i++) {
      final doc = ShipmentDocument(
        id: const Uuid().v4(),
        billOfLadingId: bolId,
        docType: widget.docType,
        imageUrl: imageUrls[i],
        amount: i == 0 ? _itemsTotal : 0.0,
        description: imageUrls.length > 1 ? 'مستند ${i + 1} من ${imageUrls.length}' : '',
        date: now,
        uploadedByName: widget.appUser.name,
      );
      await FirestoreService.instance.insertShipmentDocument(doc);
    }

    final invoice = await FirestoreService.instance.getOrCreateInvoiceForBillOfLading(
      bolId,
      clientId: client.id,
      clientName: client.name,
      billOfLading: billNo,
      vesselName: bol.vesselName,
      containerCount: containerCount,
      declarationNo: declarationCtrl.text.trim(),
    );
    final newItems = validItems
        .map((it) => InvoiceItem(
              description: it.descCtrl.text.trim(),
              amount: double.tryParse(it.amountCtrl.text.trim()) ?? 0,
              category: widget.docType,
            ))
        .toList();
    await FirestoreService.instance.addItemsToInvoice(invoice, newItems);

    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المستند وربطه بملف العميل بنجاح')));

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(billOfLadingId: bolId)),
      (route) => route.isFirst,
    );
  }

  // ---------------- مسار الموظف: إرسال للمراجعة ----------------

  Future<void> _submitForReview(List<_ItemRow> validItems) async {
    final billNo = billOfLadingCtrl.text.trim();
    final clientName = clientNameCtrl.text.trim();

    // نرفع الصور تحت معرف العميل إن كان معروفاً مسبقاً، وإلا تحت مجلد "غير_معتمد"
    // مؤقتاً لحين موافقة المدير (لن تُنقل الصورة فعلياً لاحقاً، فقط يُربط رابطها
    // منطقياً بملف العميل الصحيح عند الاعتماد).
    final clientKey = selectedClient?.id ?? 'pending_${const Uuid().v4()}';
    final imageUrls = await StorageService.instance.uploadDocumentImages(
      files: widget.imageFiles,
      clientKey: clientKey,
      billNumber: billNo,
    );

    final pending = PendingDocument(
      id: '',
      docType: widget.docType,
      clientNameInput: clientName,
      existingClientId: selectedClient?.id,
      billNumber: billNo,
      items: validItems
          .map((it) => PendingItem(
                description: it.descCtrl.text.trim(),
                amount: double.tryParse(it.amountCtrl.text.trim()) ?? 0,
              ))
          .toList(),
      imageUrls: imageUrls,
      uploadedByUid: widget.appUser.uid,
      uploadedByName: widget.appUser.name,
      date: DateFormat('yyyy/MM/dd').format(DateTime.now()),
    );
    await FirestoreService.instance.submitPendingDocument(pending);

    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال المستند للمراجعة، بانتظار موافقة المدير')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String get _categoryLabel => DocType.label(widget.docType);

  @override
  void dispose() {
    clientNameCtrl.dispose();
    billOfLadingCtrl.dispose();
    declarationCtrl.dispose();
    vesselCtrl.dispose();
    containerCountCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('بيانات $_categoryLabel')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (!isManager)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيُرسل هذا المستند للمدير للمراجعة والاعتماد قبل حفظه في ملف العميل.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

            if (widget.imageFiles.isNotEmpty) ...[
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.imageFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(widget.imageFiles[i], width: 90, height: 90, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            DropdownButtonFormField<Client>(
              decoration: const InputDecoration(
                labelText: 'اختر عميلاً مسجلاً (اختياري)',
                border: OutlineInputBorder(),
              ),
              items: availableClients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
              onChanged: (val) {
                setState(() {
                  selectedClient = val;
                  if (val != null) clientNameCtrl.text = val.name;
                });
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: clientNameCtrl,
              decoration: InputDecoration(
                labelText: 'اسم العميل *',
                helperText: isManager
                    ? 'إن كان اسماً جديداً سيُضاف تلقائياً إلى دليل العملاء'
                    : 'إن كان عميلاً جديداً سيُعتمد بواسطة المدير أولاً',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب إدخال اسم العميل' : null,
              onChanged: (_) {
                if (selectedClient != null && clientNameCtrl.text.trim() != selectedClient!.name) {
                  setState(() => selectedClient = null);
                }
              },
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: billOfLadingCtrl,
              decoration: InputDecoration(
                labelText: 'رقم البوليصة *',
                border: const OutlineInputBorder(),
                helperText: widget.ocrResult.billNo.isEmpty
                    ? 'لم يتم العثور على رقم البوليصة في الصورة - أدخله يدوياً'
                    : 'تم العثور على الرقم تلقائياً من الصورة - تحقق منه',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'رقم البوليصة مطلوب' : null,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المبلغ:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366))),
                TextButton.icon(
                  onPressed: _addItemRow,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('إضافة بند آخر'),
                ),
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: item.descCtrl,
                          decoration: const InputDecoration(labelText: 'البيان', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: item.amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder(), isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_items.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeItemRow(index),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (_itemsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(_itemsError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('إجمالي هذا المستند: ${_itemsTotal.toStringAsFixed(2)} SDG', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            if (isManager) ...[
              InkWell(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Row(
                  children: [
                    Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF003366)),
                    const Text('بيانات إضافية (اختياري)', style: TextStyle(color: Color(0xFF003366), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (_showAdvanced) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: declarationCtrl,
                        decoration: const InputDecoration(labelText: 'رقم الإقرار الجمركي', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: vesselCtrl,
                        decoration: const InputDecoration(labelText: 'اسم الباخرة', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: containerCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الحاويات',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 25),
            ],

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isManager ? Icons.save : Icons.send, color: Colors.white),
              label: Text(
                isSaving ? 'جاري الحفظ...' : (isManager ? 'حفظ وربط بملف العميل' : 'إرسال للمراجعة'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              onPressed: isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
