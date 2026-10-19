import 'dart:convert';
import 'activity_identity_aliases.dart';
import 'import_preview.dart';
import 'snapshot_store.dart';

({
  Map<String, String> targets,
  int matches,
  int canonicalChanges,
  int ambiguities,
})
reconcileActivitySignatures(
  LocalSnapshot state,
  List<Map<String, dynamic>> incoming,
) {
  final identities = _signatureGroups(state, incoming);
  final targets = <String, String>{
    for (final node in identities.nodes)
      for (final source in node.sources) source: node.id,
  };
  var matches = 0;
  var ambiguities = 0;
  final canonicalIds = <String, String>{};
  for (final group in identities.groups.values) {
    final nodes = group.values.toList();
    final positive = nodes
        .where((node) => BigInt.parse(node.id) > BigInt.zero)
        .toList();
    if (nodes.length < 2 || nodes.every((node) => node.local)) continue;
    if (nodes.length > 2 || positive.length > 1) {
      ambiguities++;
      continue;
    }
    matches++;
    final canonical = _canonicalId(nodes, positive);
    for (final node in nodes) {
      canonicalIds[node.id] = canonical;
      for (final source in node.sources) {
        targets[source] = canonical;
      }
    }
  }
  final canonicalChanges = _rekeyMatchedLocals(
    state,
    identities.nodes,
    canonicalIds,
  );
  return (
    targets: targets,
    matches: matches,
    canonicalChanges: canonicalChanges,
    ambiguities: ambiguities,
  );
}

int _rekeyMatchedLocals(
  LocalSnapshot state,
  Iterable<_SignatureNode> nodes,
  Map<String, String> canonicalIds,
) {
  var canonicalChanges = 0;
  for (final node in nodes) {
    final oldId = node.localId;
    if (oldId == null || !oldId.startsWith('-')) continue;
    final canonical = canonicalIds[node.id] ?? node.id;
    if (oldId != canonical || canonicalIds.containsKey(node.id)) {
      _rekeyLocal(state, oldId, canonical);
      if (oldId != canonical) canonicalChanges++;
    }
  }
  return canonicalChanges;
}

String _canonicalId(List<_SignatureNode> nodes, List<_SignatureNode> positive) {
  if (positive.isNotEmpty) return positive.single.id;
  final local = nodes.where((node) => node.local).toList();
  if (local.isNotEmpty) return local.single.id;
  final ordered = nodes.map((node) => node.id).toList()
    ..sort((a, b) => BigInt.parse(a).compareTo(BigInt.parse(b)));
  return ordered.first;
}

({
  Map<String, Map<String, _SignatureNode>> groups,
  Iterable<_SignatureNode> nodes,
})
_signatureGroups(LocalSnapshot state, List<Map<String, dynamic>> incoming) {
  final virtual = Map<String, Object?>.from(state.stores['activities'] ?? {});
  final nodes = <String, _SignatureNode>{
    for (final id in virtual.keys) id: _SignatureNode(id, true),
  };
  final identities = MergeActivityIdentities(
    virtual,
    incoming.map((row) => row['id'] as String),
  );
  for (final input in incoming) {
    _upgradeVirtualAlias(virtual, nodes, identities, input);
    final id = identities.resolve(input);
    final node = nodes.putIfAbsent(id, () => _SignatureNode(id, false));
    node.sources.add(input['id'] as String);
    final row = _virtualRow(virtual[id], id, input);
    virtual[id] = row;
    identities.index(id, row);
  }
  final groups = <String, Map<String, _SignatureNode>>{};
  for (final node in nodes.values) {
    final data = jsonDecode((virtual[node.id] as Map)['data'] as String) as Map;
    _addSignature(groups, node, data);
  }
  return (groups: groups, nodes: nodes.values);
}

void _upgradeVirtualAlias(
  Map<String, Object?> virtual,
  Map<String, _SignatureNode> nodes,
  MergeActivityIdentities identities,
  Map<String, dynamic> input,
) {
  final id = input['id'] as String;
  if (BigInt.parse(id) <= BigInt.zero) return;
  identities.resolve(input);
  final oldId = identities.aliasIdentity(input);
  if (oldId == null || oldId == id) return;
  if (virtual.containsKey(id)) {
    _absorbIncomingAlias(virtual, nodes, identities, oldId, id);
    return;
  }
  if (!oldId.startsWith('-')) {
    throw const BackupMergeConflict(
      'A saved identity belongs to another remote workout.',
    );
  }
  final previous = nodes.remove(oldId);
  if (previous == null) throw StateError('Missing saved workout identity.');
  final row = Map<String, Object?>.from(virtual.remove(oldId) as Map);
  final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
  data['id'] = int.parse(id);
  virtual[id] = {...row, 'id': int.parse(id), 'data': jsonEncode(data)};
  final node = _SignatureNode(id, previous.local, localId: previous.localId);
  node.sources.addAll(previous.sources);
  nodes[id] = node;
  identities.rekeyContexts(oldId, id);
}

void _absorbIncomingAlias(
  Map<String, Object?> virtual,
  Map<String, _SignatureNode> nodes,
  MergeActivityIdentities identities,
  String oldId,
  String id,
) {
  final previous = nodes[oldId];
  final destination = nodes[id];
  if (!oldId.startsWith('-') ||
      previous == null ||
      destination == null ||
      previous.local) {
    throw const BackupMergeConflict('Saved workout identities are ambiguous.');
  }
  final row = virtual.remove(oldId) as Map;
  final input = jsonDecode(row['data'] as String) as Map<String, dynamic>;
  input['id'] = oldId;
  input['identity_aliases'] = row['identity_aliases'];
  final merged = _virtualRow(virtual[id], id, input);
  virtual[id] = merged;
  destination.sources.addAll(previous.sources);
  nodes.remove(oldId);
  identities.rekeyContexts(oldId, id);
  identities.index(id, merged);
}

Map<String, Object?> _virtualRow(
  Object? existing,
  String id,
  Map<String, dynamic> input,
) {
  final data = {...input, 'id': int.parse(id)}
    ..remove('identity_aliases')
    ..remove('is_local');
  final row = existing is Map
      ? Map<String, Object?>.from(existing)
      : <String, Object?>{
          'id': int.parse(id),
          'data': jsonEncode(data),
          'synced_at': 0,
        };
  final aliases = <String, Map<String, dynamic>>{};
  for (final alias in [
    ...validatedActivityAliases(row['identity_aliases']),
    ...validatedActivityAliases(input['identity_aliases'], owner: input),
    if ((input['id'] as String).startsWith('-')) activityIdentityContext(input),
  ]) {
    aliases[activityAliasKey(alias)] = alias;
  }
  if (aliases.isNotEmpty) row['identity_aliases'] = aliases.values.toList();
  return row;
}

void _addSignature(
  Map<String, Map<String, _SignatureNode>> groups,
  _SignatureNode node,
  Map data,
) {
  if (node.id == '0' || data['distance'] == 0) return;
  final context = activityIdentityContext(data, sourceId: node.id);
  final signature = jsonEncode([
    context['type'],
    context['start_date'],
    context['distance_meters'],
  ]);
  (groups[signature] ??= {})[node.id] = node;
}

void _rekeyLocal(LocalSnapshot state, String oldId, String canonical) {
  final rows = state.stores['activities'] ?? {};
  if (oldId != canonical && rows.containsKey(canonical)) {
    throw const BackupMergeConflict('The canonical workout already exists.');
  }
  final row = Map<String, Object?>.from(rows.remove(oldId) as Map);
  final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
  final aliases = <String, Map<String, dynamic>>{};
  for (final alias in [
    ...validatedActivityAliases(row['identity_aliases'], owner: data),
    activityIdentityContext(data, sourceId: oldId),
  ]) {
    aliases[activityAliasKey(alias)] = alias;
  }
  data['id'] = int.parse(canonical);
  final keys = aliases.keys.toList()..sort();
  rows[canonical] = {
    ...row,
    'id': int.parse(canonical),
    'data': jsonEncode(data),
    'identity_aliases': [for (final key in keys) aliases[key]],
  };
  state.stores['activities'] = rows;
  if (oldId != canonical) _rekeyLinks(state, oldId, canonical);
}

void _rekeyLinks(LocalSnapshot state, String oldId, String canonical) {
  final streams = state.stores['hr_streams'] ?? {};
  final stream = streams.remove(oldId);
  if (stream is Map) {
    streams[canonical] = {...stream, 'activity_id': int.parse(canonical)};
  }
  state.stores['hr_streams'] = streams;
  state.stores['rehab_feedback'] = (state.stores['rehab_feedback'] ?? {}).map((
    id,
    value,
  ) {
    final row = Map<String, Object?>.from(value as Map);
    if ('${row['activity_id']}' == oldId) row['activity_id'] = canonical;
    return MapEntry(id, row);
  });
}

class _SignatureNode {
  final String id;
  final String? localId;
  final Set<String> sources = {};
  bool get local => localId != null;
  _SignatureNode(this.id, bool local, {String? localId})
    : localId = local ? localId ?? id : null;
}
