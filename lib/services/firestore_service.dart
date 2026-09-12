import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/bill_of_lading.dart';
import '../models/clearance_invoice.dart';
import '../models/payment.dart';
import '../models/shipment_document.dart';
import '../models/pending_document.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _clients => _db.collection('clients');
  CollectionReference get _bols => _db.collection('bill_of_ladings');
  CollectionReference get _invoices => _db.collection('invoices');
  CollectionReference get _payments => _db.collection('payments');
  CollectionReference get _documents => _db.collection('shipment_documents');
  CollectionReference get _pending => _db.collection('pending_documents');

  String _today() => DateFormat('yyyy/MM/dd').format(DateTime.now());

  // ==================== العملاء ====================

  Future<List<Client>> getClients() async {
    final snap = await _clients.orderBy('name').get();
    return snap.docs.map((d) => Client.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<Client?> getClientById(String id) async {
    final doc = await _clients.doc(id).get();
    if (!doc.exists) return null;
    return Client.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> insertClient(Client client) async {
    await _clients.doc(client.id).set(client.toMap());
  }

  /// يحذف عميلاً بالكامل مع كل بوالصه وفواتيره ومستنداته ومدفوعاته المرتبطة
  /// به (حذف متتالي/cascade). يُستخدم من المدير فقط.
  Future<void> deleteClient(String clientId) async {
    final bolsSnap = await _bols.where('clientId', isEqualTo: clientId).get();
    for (final bolDoc in bolsSnap.docs) {
      await deleteBillOfLading(bolDoc.id);
    }
    await _clients.doc(clientId).delete();
  }

  /// يبحث عن عميل معتمَد بنفس الاسم، وإلا يُنشئ عميلاً جديداً معتمَداً مباشرة.
  /// يُستخدم فقط في مسار المدير (رفع مباشر بدون مراجعة).
  Future<Client> findOrCreateClientByName(String name, {String createdByName = ''}) async {
    final cleaned = name.trim();
    final clients = await getClients();
    for (final c in clients) {
      if (c.name.trim().toLowerCase() == cleaned.toLowerCase()) return c;
    }
    final newClient = Client(
      id: const Uuid().v4(),
      name: cleaned,
      phone: '',
      taxNumber: '',
      address: '',
      advanceBalance: 0.0,
      createdByName: createdByName,
    );
    await insertClient(newClient);
    return newClient;
  }

  // ==================== بوالص الشحن ====================

  Future<List<BillOfLading>> getBillOfLadingsForClient(String clientId) async {
    final snap = await _bols.where('clientId', isEqualTo: clientId).orderBy('date', descending: true).get();
    return snap.docs.map((d) => BillOfLading.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<BillOfLading?> getBillOfLadingById(String id) async {
    final doc = await _bols.doc(id).get();
    if (!doc.exists) return null;
    return BillOfLading.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<BillOfLading?> findBillOfLading(String billNumber, String clientId) async {
    if (billNumber.trim().isEmpty) return null;
    final snap = await _bols
        .where('clientId', isEqualTo: clientId)
        .where('billNumber', isEqualTo: billNumber.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return BillOfLading.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  Future<void> insertBillOfLading(BillOfLading bol) async {
    await _bols.doc(bol.id).set(bol.toMap());
  }

  /// يحذف بوليصة واحدة بكل ما يتبعها: الفاتورة الموحّدة، كل المدفوعات، وكل
  /// المستندات المعتمدة المرتبطة بها (لا يحذف الصور من Cloudinary، فقط سجلاتها
  /// من قاعدة البيانات). يُستخدم من المدير فقط.
  Future<void> deleteBillOfLading(String billOfLadingId) async {
    final paymentsSnap = await _payments.where('billOfLadingId', isEqualTo: billOfLadingId).get();
    for (final d in paymentsSnap.docs) {
      await d.reference.delete();
    }
    final docsSnap = await _documents.where('billOfLadingId', isEqualTo: billOfLadingId).get();
    for (final d in docsSnap.docs) {
      await d.reference.delete();
    }
    await _invoices.doc(billOfLadingId).delete();
    await _bols.doc(billOfLadingId).delete();
  }

  // ==================== الفاتورة الموحّدة لكل بوليصة ====================
  // نستخدم عمداً معرّف الفاتورة = معرّف البوليصة نفسه، حتى تبقى فاتورة واحدة
  // فقط لكل بوليصة بدون الحاجة لأي عمليات دمج أو استعلام إضافي.

  Future<ClearanceInvoice> getOrCreateInvoiceForBillOfLading(
    String billOfLadingId, {
    required String clientId,
    required String clientName,
    required String billOfLading,
    String vesselName = '',
    int containerCount = 0,
    String declarationNo = '',
  }) async {
    final doc = await _invoices.doc(billOfLadingId).get();
    if (doc.exists) {
      return ClearanceInvoice.fromMap(doc.data() as Map<String, dynamic>);
    }
    final invoice = ClearanceInvoice(
      id: billOfLadingId,
      billOfLadingId: billOfLadingId,
      clientId: clientId,
      clientName: clientName,
      declarationNo: declarationNo,
      billOfLading: billOfLading,
      vesselName: vesselName,
      containerCount: containerCount,
      date: _today(),
      docTypes: const [],
      items: [],
    );
    await _invoices.doc(billOfLadingId).set(invoice.toMap());
    return invoice;
  }

  Future<void> saveInvoiceWithItems(ClearanceInvoice invoice) async {
    invoice.recomputeCategoryTotals();
    await _invoices.doc(invoice.id).set(invoice.toMap());
  }

  Future<ClearanceInvoice> addItemsToInvoice(ClearanceInvoice invoice, List<InvoiceItem> newItems) async {
    invoice.items = [...invoice.items, ...newItems];
    for (final it in newItems) {
      if (!invoice.docTypes.contains(it.category)) {
        invoice.docTypes = [...invoice.docTypes, it.category];
      }
    }
    await saveInvoiceWithItems(invoice);
    return invoice;
  }

  // ==================== المدفوعات ====================

  Future<void> insertPayment(Payment payment) async {
    await _payments.doc(payment.id).set(payment.toMap());
  }

  Future<List<Payment>> getPaymentsForBillOfLading(String billOfLadingId) async {
    final snap = await _payments.where('billOfLadingId', isEqualTo: billOfLadingId).orderBy('date').get();
    return snap.docs.map((d) => Payment.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<void> deletePayment(String id) async {
    await _payments.doc(id).delete();
  }

  // ==================== المستندات المعتمدة ====================

  Future<void> insertShipmentDocument(ShipmentDocument doc) async {
    await _documents.doc(doc.id).set(doc.toMap());
  }

  Future<List<ShipmentDocument>> getDocumentsForBillOfLading(String billOfLadingId) async {
    final snap = await _documents.where('billOfLadingId', isEqualTo: billOfLadingId).get();
    return snap.docs.map((d) => ShipmentDocument.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  /// يحذف صورة/مستند واحد فقط من ملف البوليصة (لا يحذف بقية المستندات ولا
  /// الفاتورة). يُستخدم من المدير فقط.
  Future<void> deleteShipmentDocument(String documentId) async {
    await _documents.doc(documentId).delete();
  }

  // ==================== المستندات المعلّقة (بانتظار اعتماد المدير) ====================

  Future<void> submitPendingDocument(PendingDocument pending) async {
    await _pending.add(pending.toMap());
  }

  Future<List<PendingDocument>> getPendingDocuments({String status = 'pending'}) async {
    final snap = await _pending.where('status', isEqualTo: status).orderBy('date', descending: true).get();
    return snap.docs.map((d) => PendingDocument.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();
  }

  /// عدد الطلبات المعلّقة (لعرض شارة تنبيه للمدير) بشكل لحظي.
  Stream<int> streamPendingCount() {
    return _pending.where('status', isEqualTo: 'pending').snapshots().map((s) => s.docs.length);
  }

  /// اعتماد مستند معلّق: يُنشئ/يجلب العميل والبوليصة والفاتورة الموحّدة،
  /// يضيف البنود والمستندات المعتمدة فعلياً داخل ملف العميل.
  Future<void> approvePendingDocument(PendingDocument pd, {required String reviewerName}) async {
    final client = pd.existingClientId != null
        ? (await getClientById(pd.existingClientId!)) ?? await findOrCreateClientByName(pd.clientNameInput, createdByName: pd.uploadedByName)
        : await findOrCreateClientByName(pd.clientNameInput, createdByName: pd.uploadedByName);

    var bol = await findBillOfLading(pd.billNumber, client.id);
    final bolId = bol?.id ?? const Uuid().v4();
    if (bol == null) {
      bol = BillOfLading(
        id: bolId,
        billNumber: pd.billNumber,
        clientId: client.id,
        clientName: client.name,
        vesselName: '',
        containerCount: 0,
        date: _today(),
      );
      await insertBillOfLading(bol);
    }

    final invoice = await getOrCreateInvoiceForBillOfLading(
      bolId,
      clientId: client.id,
      clientName: client.name,
      billOfLading: pd.billNumber,
      vesselName: bol.vesselName,
      containerCount: bol.containerCount,
    );
    final newItems = pd.items
        .map((it) => InvoiceItem(description: it.description, amount: it.amount, category: pd.docType))
        .toList();
    await addItemsToInvoice(invoice, newItems);

    for (var i = 0; i < pd.imageUrls.length; i++) {
      final doc = ShipmentDocument(
        id: const Uuid().v4(),
        billOfLadingId: bolId,
        docType: pd.docType,
        imageUrl: pd.imageUrls[i],
        amount: i == 0 ? pd.totalAmount : 0.0,
        description: pd.imageUrls.length > 1 ? 'مستند ${i + 1} من ${pd.imageUrls.length}' : '',
        date: pd.date,
        uploadedByName: pd.uploadedByName,
      );
      await insertShipmentDocument(doc);
    }

    await _pending.doc(pd.id).update({
      'status': 'approved',
      'reviewedByName': reviewerName,
      'reviewedDate': _today(),
    });
  }

  Future<void> rejectPendingDocument(PendingDocument pd, {required String reviewerName, String reason = ''}) async {
    await _pending.doc(pd.id).update({
      'status': 'rejected',
      'reviewedByName': reviewerName,
      'reviewedDate': _today(),
      'rejectionReason': reason,
    });
  }
}
