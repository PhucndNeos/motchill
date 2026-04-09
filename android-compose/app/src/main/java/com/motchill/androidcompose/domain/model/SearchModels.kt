package com.motchill.androidcompose.domain.model

data class SearchChoice(
    val value: String,
    val label: String,
)

data class SearchFacetOption(
    val id: Int,
    val name: String,
    val slug: String,
) {
    val hasId: Boolean
        get() = id > 0
}

data class SearchFilterData(
    val categories: List<SearchFacetOption>,
    val countries: List<SearchFacetOption>,
)

data class SearchPagination(
    val pageIndex: Int,
    val pageSize: Int,
    val pageCount: Int,
    val totalRecords: Int,
) {
    val hasPreviousPage: Boolean
        get() = pageIndex > 1

    val hasNextPage: Boolean
        get() = pageIndex < pageCount
}

data class SearchResults(
    val records: List<MovieCard>,
    val pagination: SearchPagination,
)

