import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';

Future<T?> showSearchPickSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T item) labelOf,
  String Function(T item)? subtitleOf,
  String Function(T item)? searchOf,
  T? selected,
  String emptyMessage = 'Nenhum item encontrado.',
  int pageSize = 10,
  Widget Function(BuildContext context, T item)? trailingOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return _SearchPickSheet<T>(
        title: title,
        items: items,
        labelOf: labelOf,
        subtitleOf: subtitleOf,
        searchOf: searchOf ?? labelOf,
        selected: selected,
        emptyMessage: emptyMessage,
        pageSize: pageSize < 1 ? 10 : pageSize,
        trailingOf: trailingOf,
      );
    },
  );
}

class _SearchPickSheet<T> extends StatefulWidget {
  const _SearchPickSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.searchOf,
    required this.emptyMessage,
    required this.pageSize,
    this.subtitleOf,
    this.selected,
    this.trailingOf,
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelOf;
  final String Function(T item)? subtitleOf;
  final String Function(T item) searchOf;
  final T? selected;
  final String emptyMessage;
  final int pageSize;
  final Widget Function(BuildContext context, T item)? trailingOf;

  @override
  State<_SearchPickSheet<T>> createState() => _SearchPickSheetState<T>();
}

class _SearchPickSheetState<T> extends State<_SearchPickSheet<T>> {
  final _query = TextEditingController();
  var _page = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return [
      for (final item in widget.items)
        if (widget.searchOf(item).toLowerCase().contains(q)) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageCount = filtered.isEmpty
        ? 1
        : ((filtered.length - 1) ~/ widget.pageSize) + 1;
    final page = _page.clamp(0, pageCount - 1);
    final start = page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, filtered.length);
    final pageItems = filtered.isEmpty ? <T>[] : filtered.sublist(start, end);
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GsTheme.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                key: const Key('search-pick-query'),
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _page = 0),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.emptyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF5C6570)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        final item = pageItems[index];
                        final selected = identical(item, widget.selected) ||
                            item == widget.selected;
                        final subtitle = widget.subtitleOf?.call(item) ?? '';
                        final trailing = widget.trailingOf?.call(context, item);
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: const Color(0x14C59E39),
                          title: Text(
                            widget.labelOf(item),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: GsTheme.navy,
                            ),
                          ),
                          subtitle: subtitle.trim().isEmpty
                              ? null
                              : Text(subtitle),
                          trailing: trailing ??
                              (selected
                                  ? const Icon(
                                      Icons.check,
                                      color: GsTheme.brass,
                                    )
                                  : null),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
            if (filtered.isNotEmpty && pageCount > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('search-pick-prev'),
                      tooltip: 'Página anterior',
                      onPressed: page <= 0
                          ? null
                          : () => setState(() => _page = page - 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        'Página ${page + 1} de $pageCount · ${filtered.length} item(ns)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: GsTheme.navy,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('search-pick-next'),
                      tooltip: 'Próxima página',
                      onPressed: page >= pageCount - 1
                          ? null
                          : () => setState(() => _page = page + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
