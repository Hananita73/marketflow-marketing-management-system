import 'package:flutter/material.dart';

// ─── PALETTE ─────────────────────────────────────────────────
class _P {
  static const primary      = Color(0xFF0F4C75);
  static const primaryLight = Color(0xFF1B6CA8);
  static const bg           = Color(0xFFF0F4F8);
  static const surface      = Color(0xFFFFFFFF);
  static const textHigh     = Color(0xFF0D1B2A);
  static const textMid      = Color(0xFF4A5568);
  static const textLow      = Color(0xFF8A99AA);
  static const success      = Color(0xFF00897B);
  static const successBg    = Color(0xFFE0F2F1);
  static const danger       = Color(0xFFC62828);
  static const dangerBg     = Color(0xFFFFEBEE);
  static const warning      = Color(0xFFF57C00);
  static const warningBg    = Color(0xFFFFF3E0);
}

// ─── MODEL ───────────────────────────────────────────────────
class Customer {
  String name, email, phone, status, segment;
  DateTime joinedAt;

  Customer({
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.segment,
    required this.joinedAt,
  });

  String get initials => name.trim().split(' ')
      .take(2).map((w) => w[0].toUpperCase()).join();
}

// ─── HELPERS (top-level so all widgets can use them) ─────────
Color _sColor(String s) {
  switch (s) {
    case 'Active':   return _P.success;
    case 'Inactive': return _P.danger;
    case 'Pending':  return _P.warning;
    default:         return _P.textLow;
  }
}

Color _sBg(String s) {
  switch (s) {
    case 'Active':   return _P.successBg;
    case 'Inactive': return _P.dangerBg;
    case 'Pending':  return _P.warningBg;
    default:         return _P.bg;
  }
}

Color _segColor(String s) {
  switch (s) {
    case 'VIP':       return const Color(0xFF6A1B9A);
    case 'Corporate': return _P.primaryLight;
    default:          return _P.textMid;
  }
}

Widget _chip(String label, Color color, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withValues(alpha: .25)),
  ),
  child: Text(label,
      style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
);

String _fmtDate(DateTime d) {
  const months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ─── SCREEN ──────────────────────────────────────────────────
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final List<Customer> _customers = [
    Customer(name: 'Abebe Kebede',  email: 'abebe@gmail.com',  phone: '+251 911 234 567', status: 'Active',   segment: 'VIP',       joinedAt: DateTime(2023, 1, 10)),
    Customer(name: 'Sara Ahmed',    email: 'sara@gmail.com',   phone: '+251 922 345 678', status: 'Active',   segment: 'Corporate', joinedAt: DateTime(2023, 4, 22)),
    Customer(name: 'John Smith',    email: 'john@gmail.com',   phone: '+251 933 456 789', status: 'Inactive', segment: 'Retail',    joinedAt: DateTime(2022, 11, 5)),
    Customer(name: 'Meron Tadesse', email: 'meron@gmail.com',  phone: '+251 944 567 890', status: 'Pending',  segment: 'Retail',    joinedAt: DateTime(2024, 2, 14)),
    Customer(name: 'Daniel Girma',  email: 'daniel@gmail.com', phone: '+251 955 678 901', status: 'Active',   segment: 'Corporate', joinedAt: DateTime(2023, 8, 3)),
    Customer(name: 'Hana Bekele',   email: 'hana@gmail.com',   phone: '+251 966 789 012', status: 'Active',   segment: 'VIP',       joinedAt: DateTime(2024, 1, 5)),
  ];

  String _search       = '';
  String _filterStatus = 'All';
  String _sortBy       = 'Name';
  bool   _gridView     = false;

  final _statusFilters = ['All', 'Active', 'Inactive', 'Pending'];
  final _sortOptions   = ['Name', 'Joined ↑', 'Joined ↓'];

  // ── computed ─────────────────────────────────────────────
  List<Customer> get _filtered {
    var list = _filterStatus == 'All'
        ? List<Customer>.from(_customers)
        : _customers.where((c) => c.status == _filterStatus).toList();

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q)).toList();
    }

    switch (_sortBy) {
      case 'Joined ↑': list.sort((a, b) => a.joinedAt.compareTo(b.joinedAt)); break;
      case 'Joined ↓': list.sort((a, b) => b.joinedAt.compareTo(a.joinedAt)); break;
      default:         list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  int get _activeCount   => _customers.where((c) => c.status == 'Active').length;
  int get _inactiveCount => _customers.where((c) => c.status == 'Inactive').length;
  int get _pendingCount  => _customers.where((c) => c.status == 'Pending').length;

  // ── add / edit dialog ────────────────────────────────────
  void _showDialog({Customer? existing}) {
    final isEdit    = existing != null;
    final nameCtrl  = TextEditingController(text: existing?.name  ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String status   = existing?.status  ?? 'Active';
    String segment  = existing?.segment ?? 'Retail';
    final formKey   = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // dialog title
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _P.primary.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                            color: _P.primary, size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEdit ? 'Edit Customer' : 'New Customer',
                          style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: _P.textHigh,
                          ),
                        ),
                      ]),
                      const Divider(height: 28),

                      _lbl('Full Name'),
                      _fld(nameCtrl, 'e.g. Abebe Kebede',
                          Icons.person_outline_rounded,
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 14),

                      _lbl('Email Address'),
                      _fld(emailCtrl, 'name@email.com',
                          Icons.email_outlined,
                          type: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.isEmpty) return 'Required';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          }),
                      const SizedBox(height: 14),

                      _lbl('Phone Number'),
                      _fld(phoneCtrl, '+251 9XX XXX XXX',
                          Icons.phone_outlined,
                          type: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _lbl('Status'),
                            _ddField(
                              value: status,
                              items: ['Active', 'Inactive', 'Pending'],
                              icon: Icons.toggle_on_rounded,
                              onChanged: (v) => setLocal(() => status = v!),
                            ),
                          ],
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _lbl('Segment'),
                            _ddField(
                              value: segment,
                              items: ['Retail', 'Corporate', 'VIP'],
                              icon: Icons.label_outline_rounded,
                              onChanged: (v) => setLocal(() => segment = v!),
                            ),
                          ],
                        )),
                      ]),
                      const SizedBox(height: 24),

                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _P.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            setState(() {
                              if (isEdit) {
                                existing
                                  ..name    = nameCtrl.text.trim()
                                  ..email   = emailCtrl.text.trim()
                                  ..phone   = phoneCtrl.text.trim()
                                  ..status  = status
                                  ..segment = segment;
                              } else {
                                _customers.add(Customer(
                                  name:     nameCtrl.text.trim(),
                                  email:    emailCtrl.text.trim(),
                                  phone:    phoneCtrl.text.trim(),
                                  status:   status,
                                  segment:  segment,
                                  joinedAt: DateTime.now(),
                                ));
                              }
                            });
                            Navigator.pop(ctx);
                            _snack(
                              isEdit ? 'Customer updated' : 'Customer added',
                              Icons.check_circle_rounded, _P.success,
                            );
                          },
                          child: Text(isEdit ? 'Save Changes' : 'Add Customer'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── delete confirm ───────────────────────────────────────
  void _confirmDelete(Customer c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer',
            style: TextStyle(color: _P.danger, fontWeight: FontWeight.w700)),
        content: Text('Remove "${c.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _P.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() => _customers.remove(c));
              Navigator.pop(ctx);
              _snack('Customer removed', Icons.delete_rounded, _P.danger);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── detail bottom sheet ──────────────────────────────────
  void _showDetail(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(customer: c),
    );
  }

  // ── snackbar ─────────────────────────────────────────────
  void _snack(String msg, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Management',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text('Track and manage your customers',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _gridView ? 'List view' : 'Grid view',
            icon: Icon(_gridView
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.download_rounded),
            onPressed: () =>
                _snack('Export coming soon', Icons.info_rounded, _P.primaryLight),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        backgroundColor: _P.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Customer',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        // ── stat bar ──
        Container(
          color: _P.primary,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(children: [
            _StatTile('Total',    '${_customers.length}', Icons.people_rounded,        Colors.white),
            _StatTile('Active',   '$_activeCount',        Icons.check_circle_rounded,  Colors.green.shade300),
            _StatTile('Inactive', '$_inactiveCount',      Icons.cancel_rounded,        Colors.red.shade300),
            _StatTile('Pending',  '$_pendingCount',       Icons.hourglass_top_rounded, Colors.orange.shade300),
          ]),
        ),

        // ── search + filter bar ──
        Container(
          color: _P.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: _P.bg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            _pill(
              value: _filterStatus, items: _statusFilters,
              icon: Icons.filter_list_rounded,
              onChanged: (v) => setState(() => _filterStatus = v!),
            ),
            const SizedBox(width: 8),
            _pill(
              value: _sortBy, items: _sortOptions,
              icon: Icons.sort_rounded,
              onChanged: (v) => setState(() => _sortBy = v!),
            ),
          ]),
        ),

        // ── results count ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(children: [
            Text(
              '${filtered.length} customer${filtered.length == 1 ? '' : 's'} found',
              style: const TextStyle(fontSize: 12, color: _P.textLow),
            ),
          ]),
        ),

        // ── list / grid ──
        Expanded(
          child: filtered.isEmpty
              ? _empty()
              : _gridView
                  ? _buildGrid(filtered)
                  : _buildList(filtered),
        ),
      ]),
    );
  }

  Widget _buildList(List<Customer> list) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: list.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) => _ListTile(
      customer: list[i],
      onEdit:   () => _showDialog(existing: list[i]),
      onDelete: () => _confirmDelete(list[i]),
      onTap:    () => _showDetail(list[i]),
    ),
  );

  Widget _buildGrid(List<Customer> list) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, childAspectRatio: .85,
      crossAxisSpacing: 12, mainAxisSpacing: 12,
    ),
    itemCount: list.length,
    itemBuilder: (_, i) => _GridCard(
      customer: list[i],
      onEdit:   () => _showDialog(existing: list[i]),
      onDelete: () => _confirmDelete(list[i]),
      onTap:    () => _showDetail(list[i]),
    ),
  );

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      const Text('No customers found',
          style: TextStyle(color: _P.textMid, fontSize: 16)),
      const SizedBox(height: 6),
      const Text('Adjust your search or filters',
          style: TextStyle(color: _P.textLow, fontSize: 13)),
    ]),
  );

  // ── form helpers ──────────────────────────────────────────
  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: _P.textHigh)),
  );

  Widget _fld(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: type,
        validator: validator,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _P.textLow),
          prefixIcon: Icon(icon, size: 18, color: _P.textLow),
          filled: true, fillColor: _P.bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _P.primary, width: 1.6)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _P.danger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _P.danger, width: 1.6)),
        ),
      );

  Widget _ddField({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _P.textLow),
          filled: true, fillColor: _P.bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _P.primary, width: 1.6)),
        ),
        items: items
            .map((i) => DropdownMenuItem(
                value: i,
                child: Text(i, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: onChanged,
      );

  Widget _pill<T>({
    required T value,
    required List<T> items,
    required IconData icon,
    required ValueChanged<T?> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _P.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value, isDense: true,
            icon: Icon(icon, size: 16, color: _P.primary),
            style: const TextStyle(fontSize: 12, color: _P.textHigh),
            items: items
                .map((i) => DropdownMenuItem(
                    value: i, child: Text(i.toString())))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}

// ─── STAT TILE ───────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ]),
  );
}

// ─── LIST TILE ───────────────────────────────────────────────
class _ListTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit, onDelete, onTap;
  const _ListTile({
    required this.customer, required this.onEdit,
    required this.onDelete, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _P.primary.withValues(alpha: .1),
          child: Text(customer.initials, style: const TextStyle(
              color: _P.primary, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer.name, style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _P.textHigh, fontSize: 14)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.email_outlined, size: 12, color: _P.textLow),
              const SizedBox(width: 4),
              Expanded(child: Text(customer.email,
                  style: const TextStyle(fontSize: 12, color: _P.textLow),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 12, color: _P.textLow),
              const SizedBox(width: 4),
              Text(customer.phone,
                  style: const TextStyle(fontSize: 12, color: _P.textLow)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _chip(customer.status,
                  _sColor(customer.status), _sBg(customer.status)),
              const SizedBox(width: 6),
              _chip(customer.segment,
                  _segColor(customer.segment),
                  _segColor(customer.segment).withValues(alpha: .1)),
            ]),
          ],
        )),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: _P.textLow, size: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'edit') { onEdit(); } else { onDelete(); }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, size: 16),
                  SizedBox(width: 8), Text('Edit')
                ])),
            const PopupMenuItem(value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_rounded, size: 16, color: _P.danger),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: _P.danger))
                ])),
          ],
        ),
      ]),
    ),
  );
}

// ─── GRID CARD ───────────────────────────────────────────────
class _GridCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit, onDelete, onTap;
  const _GridCard({
    required this.customer, required this.onEdit,
    required this.onDelete, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: _P.textLow, size: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'edit') { onEdit(); } else { onDelete(); }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 16),
                    SizedBox(width: 8), Text('Edit')
                  ])),
              const PopupMenuItem(value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded, size: 16, color: _P.danger),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: _P.danger))
                  ])),
            ],
          ),
        ]),
        CircleAvatar(
          radius: 28,
          backgroundColor: _P.primary.withValues(alpha: .1),
          child: Text(customer.initials, style: const TextStyle(
              color: _P.primary, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        const SizedBox(height: 10),
        Text(customer.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _P.textHigh, fontSize: 14)),
        const SizedBox(height: 4),
        Text(customer.email,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: _P.textLow)),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6, runSpacing: 6,
          children: [
            _chip(customer.status,
                _sColor(customer.status), _sBg(customer.status)),
            _chip(customer.segment,
                _segColor(customer.segment),
                _segColor(customer.segment).withValues(alpha: .1)),
          ],
        ),
      ]),
    ),
  );
}

// ─── DETAIL BOTTOM SHEET ──────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final Customer customer;
  const _DetailSheet({required this.customer});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _P.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _P.primary.withValues(alpha: .1),
              child: Text(customer.initials, style: const TextStyle(
                  color: _P.primary, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _P.textHigh, fontSize: 16)),
                const SizedBox(height: 4),
                Row(children: [
                  _chip(customer.status,
                      _sColor(customer.status), _sBg(customer.status)),
                  const SizedBox(width: 6),
                  _chip(customer.segment,
                      _segColor(customer.segment),
                      _segColor(customer.segment).withValues(alpha: .1)),
                ]),
              ],
            )),
          ]),
          const Divider(height: 32),
          _detailRow(Icons.email_outlined, 'Email', customer.email),
          const SizedBox(height: 14),
          _detailRow(Icons.phone_outlined, 'Phone', customer.phone),
          const SizedBox(height: 14),
          _detailRow(Icons.calendar_today_outlined, 'Joined',
              _fmtDate(customer.joinedAt)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _P.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _detailRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 18, color: _P.textLow),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13, color: _P.textLow)),
      const Spacer(),
      Text(value, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _P.textHigh)),
    ],
  );
}