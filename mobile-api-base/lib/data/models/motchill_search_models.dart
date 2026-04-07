import 'motchill_models.dart';

class SearchChoice {
  const SearchChoice({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class SearchFacetOption {
  const SearchFacetOption({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;

  factory SearchFacetOption.fromJson(Map<String, dynamic> json) {
    return SearchFacetOption(
      id: _parseInt(json['Id']),
      name: _parseString(json['Name']),
      slug: _parseString(json['Slug']),
    );
  }

  bool get hasId => id > 0;
}

class SearchFilterData {
  const SearchFilterData({
    required this.categories,
    required this.countries,
  });

  final List<SearchFacetOption> categories;
  final List<SearchFacetOption> countries;

  factory SearchFilterData.fromJson(Map<String, dynamic> json) {
    return SearchFilterData(
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map(
            (item) => SearchFacetOption.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      countries: (json['countries'] as List<dynamic>? ?? const [])
          .map(
            (item) => SearchFacetOption.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _parseString(dynamic value) {
  if (value == null) return '';
  return '$value';
}

class SearchPagination {
  const SearchPagination({
    required this.pageIndex,
    required this.pageSize,
    required this.pageCount,
    required this.totalRecords,
  });

  final int pageIndex;
  final int pageSize;
  final int pageCount;
  final int totalRecords;

  factory SearchPagination.fromJson(Map<String, dynamic> json) {
    return SearchPagination(
      pageIndex: _parseInt(json['PageIndex']),
      pageSize: _parseInt(json['PageSize']),
      pageCount: _parseInt(json['PageCount']),
      totalRecords: _parseInt(json['TotalRecords']),
    );
  }

  bool get hasPreviousPage => pageIndex > 1;
  bool get hasNextPage => pageIndex < pageCount;
}

class SearchResults {
  const SearchResults({
    required this.records,
    required this.pagination,
  });

  final List<MovieCard> records;
  final SearchPagination pagination;

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      records: (json['Records'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                MovieCard.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      pagination: SearchPagination.fromJson(
        Map<String, dynamic>.from(json['Pagination'] as Map? ?? const {}),
      ),
    );
  }
}
