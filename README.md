News App (UIKit, MVVM, Offline)

What it does
- Fetches top headlines from NewsAPI
- Shows title, description and thumbnail
- Pull to refresh
- Search in titles
- Offline cache (shows last fetched when offline)
- Bookmarks (bonus) in a separate segment

Tech choices
- UIKit + Auto Layout + Dynamic system colors (Light/Dark)
- MVVM: `NewsViewModel` holds data and state
- Networking: `URLSession` via `APIService`
- Caching: Core Data (`NewsArticleTable`) for offline items and bookmarks
- Images: Tiny `ImageLoader` with `NSCache` (no external libs)

Project map
- App/AppDelegate, SceneDelegate, AppConstants
- Models/Services: `APIService`, `ImageLoader`
- Models/Persistance: Core Data stack in `DataStoreManager` and entity class
- ViewModels: `NewsViewModel`
- Views: `NewsViewController` (+ XIB) and `NewsTableViewCell` (+ XIB)

How it works (simple)
1) View loads -> ViewModel fetches articles
2) On success, ViewModel updates list and stores a lightweight copy in Core Data
3) If network fails, ViewModel loads the cached copy instead
4) Pull to refresh calls the same fetch
5) Search filters the currently shown list (All or Bookmarked)
6) Tapping bookmark toggles save/remove in Core Data

Configure API key
- Edit `News App/App/AppConstants.swift` and set `apiKey`

Notes
- No external libraries to keep it simple and portable
- If you prefer SDWebImage/Kingfisher, swap `ImageLoader` in `NewsTableViewCell`
- Basic unit test included for filtering (`NewsViewModelTests`)

