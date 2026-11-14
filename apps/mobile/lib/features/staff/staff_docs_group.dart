import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/staff_docs_store.dart';
import 'package:intl/intl.dart';

class StaffDocGroup {
  const StaffDocGroup({required this.name, required this.docs});

  final String name;
  final List<StaffDocument> docs;
}

List<StaffDocGroup> groupStaffDocsByName(List<StaffDocument> docs) {
  if (docs.isEmpty) return const [];
  final map = <String, List<StaffDocument>>{};
  final order = <String>[];
  for (final doc in docs) {
    final key = doc.name.trim().toLowerCase();
    if (!map.containsKey(key)) order.add(key);
    map.putIfAbsent(key, () => []).add(doc);
  }
  return [
    for (final key in order)
      StaffDocGroup(
        name: map[key]!.first.name,
        docs: [...map[key]!]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
  ];
}

String staffDocGroupStats(List<StaffDocument> docs) {
  final pending = docs.where((d) => d.requiresSignature && !d.isSigned).length;
  final signed = docs.where((d) => d.isSigned).length;
  final cloudIssues = docs.where((d) => d.needsCloudRetry).length;
  final mailIssues = docs.where((d) => d.needsMailRetry).length;
  final latest = docs.first.createdAt.toLocal();
  return [
    '${docs.length} envio(s)',
    DateFormat('dd/MM/yyyy HH:mm').format(latest),
    if (pending > 0) '$pending aguardando assinatura',
    if (signed > 0) '$signed assinado(s)',
    if (cloudIssues > 0) '$cloudIssues sem nuvem',
    if (mailIssues > 0) '$mailIssues sem e-mail',
  ].join(' · ');
}

String staffDocStatusLine(StaffDocument doc) {
  return [
    DateFormat('dd/MM/yyyy HH:mm').format(doc.createdAt.toLocal()),
    if (doc.requiresSignature && !doc.isSigned) 'Aguardando assinatura',
    if (doc.isSigned) 'Assinado por ${doc.signedBy}',
    if (!doc.cloudSynced) 'Só neste aparelho',
    if (doc.mailSent) 'E-mail enviado',
  ].join(' · ');
}

class StaffDocsGroupedList extends StatelessWidget {
  const StaffDocsGroupedList({
    super.key,
    required this.docs,
    required this.itemBuilder,
    this.groupActionsBuilder,
  });

  final List<StaffDocument> docs;
  final Widget Function(StaffDocument doc) itemBuilder;
  final Widget Function(StaffDocGroup group)? groupActionsBuilder;

  @override
  Widget build(BuildContext context) {
    final groups = groupStaffDocsByName(docs);
    return Column(
      children: [
        for (final group in groups)
          Card(
            key: Key('staff-doc-group-${group.name}'),
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: groups.length == 1,
                tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                title: Text(
                  group.docs.length > 1
                      ? '${group.name} · ${group.docs.length}'
                      : group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  staffDocGroupStats(group.docs),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5C6570),
                  ),
                ),
                children: [
                  if (groupActionsBuilder != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: groupActionsBuilder!(group),
                      ),
                    ),
                  for (final doc in group.docs) itemBuilder(doc),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
