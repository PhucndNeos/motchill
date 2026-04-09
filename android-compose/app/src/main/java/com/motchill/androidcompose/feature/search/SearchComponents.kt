package com.motchill.androidcompose.feature.search

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.motchill.androidcompose.core.designsystem.MotchillFocusCard
import com.motchill.androidcompose.core.designsystem.MotchillRemoteImage
import com.motchill.androidcompose.domain.model.MovieCard
import com.motchill.androidcompose.domain.model.SearchChoice
import com.motchill.androidcompose.domain.model.SearchFacetOption

private enum class SearchPickerKind {
    Category,
    Country,
    Type,
    Year,
    Order,
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SearchScreen(
    uiState: SearchUiState,
    onBack: () -> Unit,
    onOpenDetail: (String) -> Unit,
    onRetry: () -> Unit,
    onSearchTextChanged: (String) -> Unit,
    onSubmitSearch: () -> Unit,
    onSelectCategory: (SearchFacetOption?) -> Unit,
    onSelectCountry: (SearchFacetOption?) -> Unit,
    onSelectTypeRaw: (SearchChoice?) -> Unit,
    onSelectYear: (SearchChoice?) -> Unit,
    onSelectOrderBy: (String) -> Unit,
    onToggleLikedOnly: () -> Unit,
    onClearSearch: () -> Unit,
    onClearCategory: () -> Unit,
    onClearCountry: () -> Unit,
    onClearTypeRaw: () -> Unit,
    onClearYear: () -> Unit,
    onClearOrderBy: () -> Unit,
    onGoToPage: (Int) -> Unit,
) {
    var activePicker by remember { mutableStateOf<SearchPickerKind?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF131313),
                        Color(0xFF101010),
                        Color(0xFF050505),
                    ),
                ),
            ),
    ) {
        SearchGridContent(
            uiState = uiState,
            onBack = onBack,
            onOpenDetail = onOpenDetail,
            onRetry = onRetry,
            onSearchTextChanged = onSearchTextChanged,
            onSubmitSearch = onSubmitSearch,
            onToggleLikedOnly = onToggleLikedOnly,
            onClearSearch = onClearSearch,
            onClearCategory = onClearCategory,
            onClearCountry = onClearCountry,
            onClearTypeRaw = onClearTypeRaw,
            onClearYear = onClearYear,
            onClearOrderBy = onClearOrderBy,
            onGoToPage = onGoToPage,
            onOpenPicker = { activePicker = it },
        )

        if (activePicker != null) {
            SearchPickerSheet(
                picker = activePicker!!,
                sheetState = sheetState,
                uiState = uiState,
                onDismiss = { activePicker = null },
                onSelectCategory = {
                    onSelectCategory(it)
                    activePicker = null
                },
                onSelectCountry = {
                    onSelectCountry(it)
                    activePicker = null
                },
                onSelectTypeRaw = {
                    onSelectTypeRaw(it)
                    activePicker = null
                },
                onSelectYear = {
                    onSelectYear(it)
                    activePicker = null
                },
                onSelectOrderBy = {
                    onSelectOrderBy(it)
                    activePicker = null
                },
            )
        }
    }
}

@Composable
private fun SearchGridContent(
    uiState: SearchUiState,
    onBack: () -> Unit,
    onOpenDetail: (String) -> Unit,
    onRetry: () -> Unit,
    onSearchTextChanged: (String) -> Unit,
    onSubmitSearch: () -> Unit,
    onToggleLikedOnly: () -> Unit,
    onClearSearch: () -> Unit,
    onClearCategory: () -> Unit,
    onClearCountry: () -> Unit,
    onClearTypeRaw: () -> Unit,
    onClearYear: () -> Unit,
    onClearOrderBy: () -> Unit,
    onGoToPage: (Int) -> Unit,
    onOpenPicker: (SearchPickerKind) -> Unit,
) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(180.dp),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            SearchHeader(
                title = uiState.screenTitle,
                subtitle = uiState.screenSubtitle,
                likedOnlySelected = uiState.showLikedOnly,
                onBack = onBack,
                onToggleLikedOnly = onToggleLikedOnly,
            )
        }
        item(span = { GridItemSpan(maxLineSpan) }) {
            SearchBar(
                query = uiState.searchInputValue,
                showClear = uiState.searchInputValue.isNotEmpty(),
                onQueryChanged = onSearchTextChanged,
                onSubmit = onSubmitSearch,
                onClear = onClearSearch,
            )
        }
        item(span = { GridItemSpan(maxLineSpan) }) {
            SearchFilterStrip(
                uiState = uiState,
                onOpenPicker = onOpenPicker,
                onClearCategory = onClearCategory,
                onClearCountry = onClearCountry,
                onClearTypeRaw = onClearTypeRaw,
                onClearYear = onClearYear,
                onClearOrderBy = onClearOrderBy,
            )
        }
        item(span = { GridItemSpan(maxLineSpan) }) {
            SearchResultsHeader(
                count = uiState.visibleMovies.size,
                currentPage = uiState.currentPage,
                totalPages = uiState.totalPages,
                isUpdating = uiState.isSearching,
                canGoPrevious = uiState.canGoPrevious,
                canGoNext = uiState.canGoNext,
                onPrevious = if (uiState.canGoPrevious) ({ onGoToPage(uiState.currentPage - 1) }) else null,
                onNext = if (uiState.canGoNext) ({ onGoToPage(uiState.currentPage + 1) }) else null,
            )
        }
        when {
            uiState.isLoading && uiState.visibleMovies.isEmpty() -> {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    SearchLoadingState()
                }
            }
            uiState.errorMessage != null && uiState.visibleMovies.isEmpty() -> {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    SearchErrorState(message = uiState.errorMessage, onRetry = onRetry)
                }
            }
            uiState.visibleMovies.isEmpty() -> {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    SearchEmptyState(message = "Chưa có nội dung phù hợp")
                }
            }
            else -> {
                items(uiState.visibleMovies, key = { it.id }) { movie ->
                    SearchMovieCard(movie = movie, onClick = { onOpenDetail(movie.link) })
                }
            }
        }
    }
}

@Composable
private fun SearchHeader(
    title: String,
    subtitle: String,
    likedOnlySelected: Boolean,
    onBack: () -> Unit,
    onToggleLikedOnly: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        SearchIconButton(icon = Icons.AutoMirrored.Outlined.ArrowBack, onClick = onBack)
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Black,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (subtitle.isNotBlank()) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = subtitle,
                    color = Color.White.copy(alpha = 0.60f),
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        SearchIconButton(
            icon = if (likedOnlySelected) Icons.Outlined.Favorite else Icons.Outlined.FavoriteBorder,
            onClick = onToggleLikedOnly,
            selected = likedOnlySelected,
        )
    }
}

@Composable
private fun SearchBar(
    query: String,
    showClear: Boolean,
    onQueryChanged: (String) -> Unit,
    onSubmit: () -> Unit,
    onClear: () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = if (focused) Color(0xFF1E1E1E) else Color(0xFF1A1A1A),
                shape = RoundedCornerShape(18.dp),
            )
            .border(
                width = if (focused) 2.dp else 1.dp,
                color = if (focused) Color(0xFFE50914) else Color(0xFF2E2E2E),
                shape = RoundedCornerShape(18.dp),
            ),
    ) {
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChanged,
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged { focused = it.isFocused },
            singleLine = true,
            placeholder = { Text("Tìm phim, tập phim, diễn viên...") },
            leadingIcon = { Icon(imageVector = Icons.Outlined.Search, contentDescription = null) },
            trailingIcon = {
                if (showClear) {
                    SearchIconButton(
                        icon = Icons.Outlined.Close,
                        onClick = onClear,
                        selected = false,
                        compact = true,
                    )
                }
            },
            shape = RoundedCornerShape(18.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SearchFilterStrip(
    uiState: SearchUiState,
    onOpenPicker: (SearchPickerKind) -> Unit,
    onClearCategory: () -> Unit,
    onClearCountry: () -> Unit,
    onClearTypeRaw: () -> Unit,
    onClearYear: () -> Unit,
    onClearOrderBy: () -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth(),
        itemVerticalAlignment = Alignment.CenterVertically
    ) {
        SearchFilterChip(
            label = uiState.selectedCategoryLabel.ifBlank { "Thể loại" },
            selected = uiState.selectedCategoryLabel.isNotBlank(),
            onClick = { onOpenPicker(SearchPickerKind.Category) },
            onClear = if (uiState.selectedCategoryLabel.isNotBlank()) onClearCategory else null,
        )
        SearchFilterChip(
            label = uiState.selectedCountryLabel.ifBlank { "Quốc gia" },
            selected = uiState.selectedCountryLabel.isNotBlank(),
            onClick = { onOpenPicker(SearchPickerKind.Country) },
            onClear = if (uiState.selectedCountryLabel.isNotBlank()) onClearCountry else null,
        )
        SearchFilterChip(
            label = uiState.selectedTypeLabel.ifBlank { "Loại phim" },
            selected = uiState.selectedTypeRaw.isNotBlank(),
            onClick = { onOpenPicker(SearchPickerKind.Type) },
            onClear = if (uiState.selectedTypeRaw.isNotBlank()) onClearTypeRaw else null,
        )
        SearchFilterChip(
            label = uiState.selectedYear.ifBlank { "Năm" },
            selected = uiState.selectedYear.isNotBlank(),
            onClick = { onOpenPicker(SearchPickerKind.Year) },
            onClear = if (uiState.selectedYear.isNotBlank()) onClearYear else null,
        )
        SearchFilterChip(
            label = uiState.currentOrderLabel,
            selected = true,
            onClick = { onOpenPicker(SearchPickerKind.Order) },
            onClear = onClearOrderBy,
        )
    }
}

@Composable
private fun SearchFilterChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    onClear: (() -> Unit)?,
) {
    MotchillFocusCard(
        onClick = onClick,
        borderRadius = RoundedCornerShape(999.dp),
        focusedBorderColor = Color(0xFFFFD15C),
        focusedBackgroundColor = Color(0xFFE50914).copy(alpha = 0.22f),
        focusScale = 1.02f,
        modifier = Modifier.border(
            width = 1.dp,
            color = if (selected) Color(0xFFE50914).copy(alpha = 0.28f) else Color(0xFF303030),
            shape = RoundedCornerShape(999.dp),
        ),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = label,
                color = if (selected) Color(0xFFFFD4D0) else Color.White.copy(alpha = 0.70f),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
            )
            if (onClear != null) {
                SearchIconButton(
                    icon = Icons.Outlined.Close,
                    onClick = onClear,
                    selected = false,
                    compact = true,
                )
            }
        }
    }
}

@Composable
private fun SearchResultsHeader(
    count: Int,
    currentPage: Int,
    totalPages: Int,
    isUpdating: Boolean,
    canGoPrevious: Boolean,
    canGoNext: Boolean,
    onPrevious: (() -> Unit)?,
    onNext: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF171717), RoundedCornerShape(18.dp))
            .border(1.dp, Color(0xFF2D2D2D), RoundedCornerShape(18.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = if (count > 0) "$count kết quả" else "Không có kết quả",
            color = Color.White.copy(alpha = 0.72f),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        if (isUpdating) {
            CircularProgressIndicator(modifier = Modifier.width(18.dp).height(18.dp), strokeWidth = 2.dp)
            Spacer(modifier = Modifier.width(8.dp))
        }
        SearchPageButton(text = "‹", enabled = canGoPrevious, onClick = onPrevious)
        Spacer(modifier = Modifier.width(6.dp))
        SearchPageButton(text = "›", enabled = canGoNext, onClick = onNext)
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = if (totalPages == 0) "Trang $currentPage" else "Trang $currentPage/$totalPages",
            color = Color.White.copy(alpha = 0.55f),
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun SearchPageButton(
    text: String,
    enabled: Boolean,
    onClick: (() -> Unit)?,
) {
    MotchillFocusCard(
        onClick = { onClick?.invoke() },
        enabled = enabled && onClick != null,
        borderRadius = RoundedCornerShape(999.dp),
        focusedBorderColor = Color(0xFFFFD15C),
        focusedBackgroundColor = Color.White.copy(alpha = 0.06f),
        focusScale = 1.03f,
        modifier = Modifier.border(
            width = 1.dp,
            color = if (enabled) Color(0xFF2A2A2A) else Color(0xFF1E1E1E),
            shape = RoundedCornerShape(999.dp),
        ),
    ) {
        Box(
            modifier = Modifier
                .background(
                    color = if (enabled) Color(0xFF1A1A1A) else Color(0xFF141414),
                    shape = RoundedCornerShape(999.dp),
                )
                .padding(horizontal = 14.dp, vertical = 8.dp),
        ) {
            Text(
                text = text,
                color = if (enabled) Color.White else Color.White.copy(alpha = 0.32f),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun SearchMovieCard(
    movie: MovieCard,
    onClick: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        MotchillFocusCard(
            onClick = onClick,
            borderRadius = RoundedCornerShape(18.dp),
            focusedBorderColor = Color(0xFFFFD15C),
            focusedBackgroundColor = Color.White.copy(alpha = 0.06f),
            focusScale = 1.02f,
            modifier = Modifier
                .fillMaxWidth()
                .height(260.dp)
                .border(1.dp, Color(0xFF2A2A2A), RoundedCornerShape(18.dp))
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                MotchillRemoteImage(url = movie.displayPoster, modifier = Modifier.fillMaxSize())
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Black.copy(alpha = 0.48f), Color.Transparent),
                            ),
                        ),
                )
                if (movie.rating.isNotBlank()) {
                    SearchBadge(
                        text = movie.rating,
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .padding(start = 10.dp, top = 10.dp),
                    )
                }
            }
        }
        Text(
            text = movie.displayTitle,
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = movie.displaySubtitle.ifBlank { movie.statusTitle },
            color = Color.White.copy(alpha = 0.60f),
            fontSize = 11.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun SearchBadge(
    text: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(Color.Black.copy(alpha = 0.72f), RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        Text(text = text, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun SearchLoadingState() {
    Box(modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
private fun SearchErrorState(
    message: String?,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 36.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = message.orEmpty(), color = Color.White, fontSize = 16.sp)
        TextButton(onClick = onRetry) {
            Text("Thử lại")
        }
    }
}

@Composable
private fun SearchEmptyState(message: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(text = message, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        Text(
            text = "Hãy thử từ khóa hoặc bộ lọc khác.",
            color = Color.White.copy(alpha = 0.60f),
            fontSize = 12.sp,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SearchPickerSheet(
    picker: SearchPickerKind,
    sheetState: SheetState,
    uiState: SearchUiState,
    onDismiss: () -> Unit,
    onSelectCategory: (SearchFacetOption?) -> Unit,
    onSelectCountry: (SearchFacetOption?) -> Unit,
    onSelectTypeRaw: (SearchChoice?) -> Unit,
    onSelectYear: (SearchChoice?) -> Unit,
    onSelectOrderBy: (String) -> Unit,
) {
    val title = when (picker) {
        SearchPickerKind.Category -> "Chọn thể loại"
        SearchPickerKind.Country -> "Chọn quốc gia"
        SearchPickerKind.Type -> "Loại phim"
        SearchPickerKind.Year -> "Năm phát hành"
        SearchPickerKind.Order -> "Sắp xếp"
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState, containerColor = Color(0xFF141414)) {
        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
            val sheetMaxHeight = maxHeight * 0.5f

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = sheetMaxHeight)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                Text(text = title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                HorizontalDivider(color = Color.White.copy(alpha = 0.08f))
                Spacer(modifier = Modifier.height(8.dp))

                when (picker) {
                    SearchPickerKind.Category -> SearchOptionList(
                        options = uiState.filters.categoryOptionsWithAll(),
                        selectedFacetId = uiState.selectedCategoryId ?: 0,
                        onSelectFacet = onSelectCategory,
                    )
                    SearchPickerKind.Country -> SearchOptionList(
                        options = uiState.filters.countryOptionsWithAll(),
                        selectedFacetId = uiState.selectedCountryId ?: 0,
                        onSelectFacet = onSelectCountry,
                    )
                    SearchPickerKind.Type -> SearchChoiceList(
                        options = searchTypeOptions,
                        selectedValue = uiState.selectedTypeRaw,
                        onSelectChoice = onSelectTypeRaw,
                    )
                    SearchPickerKind.Year -> SearchChoiceList(
                        options = searchYearOptions,
                        selectedValue = uiState.selectedYear,
                        onSelectChoice = onSelectYear,
                    )
                    SearchPickerKind.Order -> SearchChoiceList(
                        options = searchOrderOptions,
                        selectedValue = uiState.selectedOrderBy,
                        onSelectChoice = { choice -> onSelectOrderBy(choice?.value.orEmpty()) },
                    )
                }
            }
        }
    }
}

@Composable
private fun SearchOptionList(
    options: List<SearchFacetOption>,
    selectedFacetId: Int,
    onSelectFacet: (SearchFacetOption?) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(options, key = { it.id }) { option ->
            SearchPickerRow(
                title = option.name,
                subtitle = option.slug.ifBlank { null },
                selected = option.id == selectedFacetId,
                onClick = { onSelectFacet(option.takeIf { it.hasId }) },
            )
        }
    }
}

@Composable
private fun SearchChoiceList(
    options: List<SearchChoice>,
    selectedValue: String,
    onSelectChoice: (SearchChoice?) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(options, key = { it.value }) { choice ->
            SearchPickerRow(
                title = choice.label,
                subtitle = if (choice.value.isNotBlank()) choice.value else null,
                selected = choice.value == selectedValue,
                onClick = { onSelectChoice(choice.takeIf { it.value.isNotBlank() }) },
            )
        }
    }
}

@Composable
private fun SearchPickerRow(
    title: String,
    subtitle: String?,
    selected: Boolean,
    onClick: () -> Unit,
) {
    MotchillFocusCard(
        onClick = onClick,
        borderRadius = RoundedCornerShape(16.dp),
        focusedBorderColor = Color(0xFFE8A7A7),
        focusedBackgroundColor = Color(0xFF251717),
        focusScale = 1.01f,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                if (!subtitle.isNullOrBlank()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(text = subtitle, color = Color.White.copy(alpha = 0.50f), fontSize = 11.sp)
                }
            }
            if (selected) {
                Icon(imageVector = Icons.Outlined.Check, contentDescription = null, tint = Color.White)
            }
        }
    }
}

@Composable
private fun SearchIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    selected: Boolean = false,
    compact: Boolean = false,
) {
    MotchillFocusCard(
        onClick = onClick,
        borderRadius = RoundedCornerShape(999.dp),
        focusedBorderColor = Color(0xFFFFD15C),
        focusedBackgroundColor = Color(0xFFE50914).copy(alpha = 0.22f),
        focusScale = 1.03f,
        modifier = Modifier.border(
            width = 1.dp,
            color = if (selected) Color(0xFFE50914).copy(alpha = 0.35f) else Color(0xFF2A2A2A),
            shape = RoundedCornerShape(999.dp),
        ),
    ) {
        Box(
            modifier = Modifier
                .background(
                    color = if (selected) Color(0xFFE50914).copy(alpha = 0.22f) else Color(0xFF1A1A1A),
                    shape = RoundedCornerShape(999.dp),
                )
                .padding(if (compact) 6.dp else 10.dp),
        ) {
            Icon(imageVector = icon, contentDescription = null, tint = Color.White)
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF101010, device = Devices.TABLET)
@Composable
private fun SearchScreenPreview() {
    SearchScreen(
        uiState = SearchMockData.loadedState(),
        onBack = {},
        onOpenDetail = {},
        onRetry = {},
        onSearchTextChanged = {},
        onSubmitSearch = {},
        onSelectCategory = {},
        onSelectCountry = {},
        onSelectTypeRaw = {},
        onSelectYear = {},
        onSelectOrderBy = {},
        onToggleLikedOnly = {},
        onClearSearch = {},
        onClearCategory = {},
        onClearCountry = {},
        onClearTypeRaw = {},
        onClearYear = {},
        onClearOrderBy = {},
        onGoToPage = {},
    )
}
