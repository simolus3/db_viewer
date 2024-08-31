import 'package:db_viewer/db_viewer.dart';
import 'package:drift/drift.dart';
import 'package:drift_db_viewer/src/model/filter/drift_filter_data.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:drift_db_viewer/src/widget/filter/where_widget.dart';

class DriftDbViewerDatabase implements DbViewerDatabase {
  final GeneratedDatabase _db;
  final _filterData = <String, FilterData>{};

  DriftDbViewerDatabase._(this._db);

  static init(GeneratedDatabase db) =>
      DbViewerDatabase.initDb(DriftDbViewerDatabase._(db));

  TableInfo<Table, dynamic>? _getTable(String tableName) {
    final tables =
        _db.allTables.where((element) => element.actualTableName == tableName);
    if (tables.isEmpty) return null;
    return tables.first;
  }

  List<String> get entityNames =>
      _db.allTables.map((e) => e.entityName).toList();

  @override
  List<String> getColumnNamesByEntityName(String tableName) =>
      _getTable(tableName)?.columnsByName.keys.toList() ?? [];

  @override
  List<Map<String, dynamic>> remapData(
      String tableName, List<Map<String, dynamic>> data) {
    final SqlTypes types = _db.typeMapping;
    final table = _getTable(tableName);
    if (table == null) return data;
    final correctData = <Map<String, dynamic>>[];
    data.forEach((item) {
      final map = <String, dynamic>{};
      item.keys.forEach((key) {
        final columns = table.$columns.where((column) => column.$name == key);
        final column = columns.isEmpty ? null : columns.first;
        if (column is GeneratedColumn<DateTime>) {
          final value = item[key];
          final dateTime = types.read(DriftSqlType.dateTime, value);
          map[key] = dateTime?.toIso8601String();
        } else if (column is GeneratedColumn<bool>) {
          final value = item[key];
          map[key] = types.read(DriftSqlType.bool, value);
        } else {
          map[key] = item[key];
        }
      });
      correctData.add(map);
    });
    return correctData;
  }

  @override
  String getType(String entityName, String columnName) {
    final entity = _getTable(entityName);
    if (entity == null) throw ArgumentError('Entity $entityName is not found');
    final column =
        entity.$columns.firstWhere((column) => column.$name == columnName);
    if (column is GeneratedColumn<DateTime>) {
      return 'DATE';
    } else if (column is GeneratedColumn<Uint8List>) {
      return 'BLOB';
    } else if (column is GeneratedColumn<double>) {
      return 'DOUBLE';
    } else if (column is GeneratedColumn<bool>) {
      return 'BOOL';
    } else if (column is GeneratedColumn<String>) {
      return 'TEXT';
    } else if (column is GeneratedColumn<int>) {
      return 'INTEGER';
    }
    return 'UNSUPPORTED TYPE';
  }

  //Queries
  @override
  Future<List<Map<String, dynamic>>> customSelect(String query,
      {Set<String>? fromEntityNames}) async {
    final result = await _db.customSelect(query).get();
    return result.map((e) => e.data).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> customSelectStream(String query,
          {Set<String>? fromEntityNames}) =>
      _db.customSelect(query).map((item) => item.data).watch();

  @override
  Future<void> runCustomStatement(String query) async =>
      await _db.customStatement(query);

  @override
  Stream<int> count(String tableName) {
    final table = _getTable(tableName);
    if (table == null) return Stream.value(0);
    final countStream = _db.customSelect('SELECT COUNT(*) FROM ${tableName}',
        readsFrom: {table}).watch();
    return countStream.map((data) => data.first.data['COUNT(*)']);
  }

  //Filter Data
  @override
  FilterData getFilterData(String tableName) {
    final table = _getTable(tableName);
    if (table == null) throw ArgumentError('$tableName is not available');
    return DriftFilterData(table, _db.typeMapping);
  }

  FilterData getCachedFilterData(String entityName) {
    if (!_filterData.containsKey(entityName)) {
      _filterData[entityName] = getFilterData(entityName);
    }
    return _filterData[entityName]!;
  }

  void updateFilterData(String entityName, FilterData filterData) {
    _filterData[entityName] = filterData;
  }

  //UI
  @override
  Widget buildWhereWidget({
    required VoidCallback onAddClicked,
    required List<WhereClause> whereClauses,
  }) =>
      WhereTitleWidget(
        onAddClicked: onAddClicked,
        whereClauses: whereClauses,
      );
}
