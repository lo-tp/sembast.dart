import 'package:sembast/sembast.dart';
import 'package:sembast/src/boundary_impl.dart';

class SembastSortOrder implements SortOrder {
  final bool ascending; // default true
  final String field;
  final bool nullLast; // default false

  ///
  /// default is [ascending] = true
  ///
  /// user withParam
  SembastSortOrder(this.field, [bool ascending, bool nullLast])
      : ascending = ascending != false,
        nullLast = nullLast == true;

  int compare(Record record1, Record record2) {
    int result = compareAscending(record1, record2);
    return ascending ? result : -result;
  }

  int compareToBoundary(Record record, Boundary boundary, int index) {
    int result = compareToBoundaryAscending(record, boundary, index);
    return ascending ? result : -result;
  }

  int compareToBoundaryAscending(Record record, Boundary boundary, int index) {
    final sembastBoundary = boundary as SembastBoundary;
    if (sembastBoundary.values != null) {
      var value = sembastBoundary.values[index];
      return compareValueAscending(record[field], value);
    }
    if (sembastBoundary.record != null) {
      return compare(record, sembastBoundary.record);
    }
    throw ArgumentError('either record or values must be provided');
  }

  int compareAscending(Record record1, Record record2) {
    var value1 = record1[field];
    var value2 = record2[field];
    return compareValueAscending(value1, value2);
  }

  int compareValueAscending(dynamic value1, dynamic value2) {
    if (value1 == null) {
      if (value2 == null) {
        return 0;
      }
      if (nullLast) {
        return 1;
      } else {
        return -1;
      }
    } else if (value2 == null) {
      if (nullLast) {
        return -1;
      } else {
        return 1;
      }
    }
    if (value1 is Comparable) {
      return value1.compareTo(value2);
    }
    return 0;
  }

  Map _toDebugMap() {
    Map map = {field: ascending ? "asc" : "desc"};
    if (nullLast == true) {
      map['nullLast'] = true;
    }
    return map;
  }

  @override
  String toString() {
    // ignore: deprecated_member_use
    return _toDebugMap.toString();
  }
}
