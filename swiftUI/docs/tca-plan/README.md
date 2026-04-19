# TCA Migration Plan

This folder breaks the SwiftUI-to-TCA migration into small, ordered tasks so we can refactor the app one piece at a time without destabilizing the current codebase.

## Progress

- Phase 1, `01-setup-tca.md`, is done.
- Phase 2, `02-app-shell-navigation.md`, is done.
- Phase 3, `03-home-feature.md`, is done.
- Phase 4, `04-search-feature.md`, is done.
- Phase 5, `05-detail-feature.md`, is done.
- Phase 6, `06-player-feature.md`, is done.
- The app now has a TCA foundation layer, a root `AppFeature`, a TCA shell navigation stack, and reducer-backed Home, Search, Detail, and Player features.
- Phase 7, `07-cleanup-stabilization.md`, is done.
- The app now uses TCA for shell flow and Supabase-only sync for liked movies and playback history.

## Reading Order

1. [00-overview.md](./00-overview.md)
2. [01-setup-tca.md](./01-setup-tca.md)
3. [01-setup-tca-result.md](./01-setup-tca-result.md)
4. [02-app-shell-navigation.md](./02-app-shell-navigation.md)
5. [02-app-shell-navigation-result.md](./02-app-shell-navigation-result.md)
6. [03-home-feature.md](./03-home-feature.md)
7. [03-home-feature-result.md](./03-home-feature-result.md)
8. [04-search-feature.md](./04-search-feature.md)
9. [04-search-feature-result.md](./04-search-feature-result.md)
10. [05-detail-feature.md](./05-detail-feature.md)
11. [05-detail-feature-result.md](./05-detail-feature-result.md)
12. [06-player-feature.md](./06-player-feature.md)
13. [06-player-feature-result.md](./06-player-feature-result.md)
14. [07-cleanup-stabilization.md](./07-cleanup-stabilization.md)
15. [07-cleanup-stabilization-result.md](./07-cleanup-stabilization-result.md)

## Migration Rules

- Work on a dedicated branch before making architectural changes.
- Migrate one feature at a time.
- Keep existing repository, storage, and Supabase layers intact during the first pass.
- Add reducer tests before removing the old MVVM code for each feature.
- Prefer small commits so each checkpoint is easy to review and revert if needed.
- Mark each completed phase in its own file before moving on.
- Keep a companion result note for each completed phase so future readers can understand the why, not just the checklist.
