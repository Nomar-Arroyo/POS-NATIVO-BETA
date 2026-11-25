import 'package:data_local/data_local.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../desktop_state.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  String _query = '';
  String _category = 'Todas';

  @override
  Widget build(BuildContext context) {
    watchDesktopNavigation(context);
    final database = context.watch<LocalDatabase>();
    final organizationId = database.localWorkspace!.organizationId;
    final rows = database.database.select(
      'SELECT action, entity_type, entity_id, profile_id, after_json, occurred_at '
      'FROM audit_logs WHERE organization_id = ? ORDER BY occurred_at DESC LIMIT 500',
      [organizationId],
    );
    final categories = <String>{
      for (final row in rows) row['entity_type'] as String,
    }.toList()..sort();
    final visible = rows
        .where((row) {
          final type = row['entity_type'] as String;
          final action = row['action'] as String;
          final matchesCategory = _category == 'Todas' || type == _category;
          final needle = _query.toLowerCase();
          final matchesQuery =
              needle.isEmpty ||
              action.toLowerCase().contains(needle) ||
              type.toLowerCase().contains(needle) ||
              (row['entity_id'] as String).toLowerCase().contains(needle);
          return matchesCategory && matchesQuery;
        })
        .toList(growable: false);
    final lastSevenDays = rows.where((row) {
      final date = DateTime.tryParse(row['occurred_at'] as String)?.toLocal();
      return date != null && DateTime.now().difference(date).inDays < 7;
    }).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'Auditoría del Sistema',
            subtitle: 'Registro inmutable de actividad local',
            trailing: OutlinedButton.icon(
              onPressed: () async {
                final text = StringBuffer('Acción,Entidad,ID,Fecha\n');
                for (final row in visible) {
                  text.writeln(
                    '${row['action']},${row['entity_type']},${row['entity_id']},${row['occurred_at']}',
                  );
                }
                await Clipboard.setData(ClipboardData(text: text.toString()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Auditoría CSV copiada al portapapeles'),
                  ),
                );
              },
              icon: const Icon(Icons.ios_share, size: 15),
              label: const Text('Copiar CSV'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'Total registros (7 días)',
                  value: '$lastSevenDays',
                  icon: AmalfiIconName.receipt,
                  valueColor: AmalfiTheme.brandFor(context),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: SummaryCard(
                  label: 'Advertencias',
                  value: '0',
                  icon: AmalfiIconName.bell,
                  valueColor: AmalfiTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'Errores',
                  value: '0',
                  icon: AmalfiIconName.close,
                  valueColor: AmalfiTheme.errorFor(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'Usuarios registrados',
                  value: rows
                      .map((row) => row['profile_id'])
                      .toSet()
                      .length
                      .toString(),
                  icon: AmalfiIconName.users,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: AmalfiPanel(
              title: 'Filtros de Auditoría',
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar en descripción...',
                        prefixIcon: AmalfiIcon(
                          name: AmalfiIconName.search,
                          size: 17,
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        const DropdownMenuItem(
                          value: 'Todas',
                          child: Text('Todas las categorías'),
                        ),
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _category = value ?? 'Todas'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _query = '';
                        _category = 'Todas';
                      }),
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                      label: const Text('Limpiar filtros'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AmalfiPanel(
              title: 'Registro de Auditoría',
              trailing: StatusBadge(
                label: '${visible.length} registros',
                color: AmalfiTheme.brandFor(context),
              ),
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No hay registros para los filtros seleccionados.',
                        style: AmalfiTheme.mutedText(context, fontSize: 11),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = visible[index];
                        final action = row['action'] as String;
                        final type = row['entity_type'] as String;
                        final date = row['occurred_at'] as String;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.history,
                            color: AmalfiTheme.mutedFor(context),
                            size: 18,
                          ),
                          title: Text(
                            action.replaceAll('_', ' '),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '$type · ${row['entity_id']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: Text(
                            date,
                            style: AmalfiTheme.mutedText(context, fontSize: 9),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los registros se conservan en este equipo. La auditoría central requiere configurar el servidor.',
            style: AmalfiTheme.mutedText(context, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
