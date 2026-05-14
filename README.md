IPAAnalyzer
A modern macOS app for analyzing and comparing iOS .ipa files with detailed insights into app size, binaries, frameworks, and assets.
Features
🔍 Single IPA Analysis


* Detailed size breakdown:
    * App binary
    * Frameworks
    * Assets
    * Plugins/extensions
    
* File tree explorer with:
    * Search
    * Sorting
    * Hierarchical navigation
    
* Binary analysis:
    * Mach-O parsing
    * Architecture detection
    * Segment analysis
    * Bitcode detection
    * Symbol count
* Framework analysis:
    * Embedded frameworks listing
    * Framework version detection
    * Duplicate framework detection
    * Size tracking
* Assets analysis:
    * Large asset detection
    * Type categorization
    * Optimization suggestions
* Interactive visualizations using Swift Charts

⚖️ IPA Comparison
* Compare two IPA files side-by-side
* Track size changes across binaries, frameworks, and assets
* Detect added, removed, and modified files
* Compare framework versions and updates
* Analyze binary architecture and segment differences
* Visual diff indicators:
    * 🟢 Added
    * 🔴 Removed
    * 🟡 Modified
* Smart filtering:
    * All changes
    * Modified only
    * Large changes (>1MB)

📊 Export Options
* JSON analysis reports
* CSV summaries
* Detailed comparison reports for CI/CD workflows

Tech Stack
* Swift 5.9+
* SwiftUI
* MVVM Architecture
* async/await concurrency
* Swift Charts
* Native FileManager APIs
* Custom Mach-O parser

Requirements
* macOS 14.0+
* Xcode 15.0+

Project Structure

IPAAnalyzer/
├── Models/
├── Services/
├── ViewModels/
└── Views/


Build & Run
<img width="1493" height="773" alt="Screenshot 2026-05-14 at 9 48 33 AM" src="https://github.com/user-attachments/assets/62c5e8d0-8d2e-4043-9ff0-f127f93bb942" />


<img width="1284" height="807" alt="Screenshot 2026-05-14 at 9 48 51 AM" src="https://github.com/user-attachments/assets/d213a764-1199-4608-8b69-450acbd58d8a" />
<img width="1277" height="807" alt="Screenshot 2026-05-14 at 9 48 58 AM" src="https://github.com/user-attachments/assets/0411f8cb-72de-40ad-b308-52a3d345b2d7" />

