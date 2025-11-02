# listen_it Documentation Update Plan

## Goal
Transform listen_it package to match the get_it quality standard:
1. **Update README.md** in `/home/escamoteur/dev/flutter_it/listen_it/` to match get_it structure
2. **Extract all code samples** into `/home/escamoteur/dev/flutter_it/docs/code_samples/lib/listen_it/`
3. **Update documentation pages** in `/home/escamoteur/dev/flutter_it/docs/docs/documentation/listen_it/`
4. **Incorporate critical lifecycle warnings** from CHAIN_LIFECYCLE_FINDINGS.md

## Part 1: Update Package README.md Structure

Match get_it README structure (193 lines):

### Header Section (similar to get_it)
- Add codecov badge (if available)
- Add sponsor links
- **Prominent flutter-it.dev link** at top
- One-line tagline

### Elevator Pitch (~3 paragraphs)
- Explain the problem (managing reactive state, observable collections)
- Introduce the solution (operators + collections)
- **Add "construction set" messaging**

### "Why listen_it?" Section (NEW)
- ⚡ **Chainable** — Transform and combine observables
- 🔔 **Reactive Collections** — Automatic notifications
- 🎯 **Selective Updates** — select() for fine-grained control
- 🔒 **Type Safe** — Full compile-time checking
- 📦 **Framework Agnostic** — Pure Dart (collections need Flutter)
- 🧪 **Test Friendly** — Easy to mock and test
- Link to detailed docs

### Quick Start (keep current, improve slightly)
- Keep collections example
- Keep operators example
- Add link to getting started guide

### Key Features (RESTRUCTURE)
Two main sections with links:

**Reactive Collections**
- ListNotifier, MapNotifier, SetNotifier
- Notification modes
- Transactions
- [Read more → link to collections docs]

**ValueListenable Operators**
- listen(), map(), select(), where()
- debounce(), combineLatest(), mergeWith()
- [Read more → link to operators docs]

### ⚠️ Important: Chain Lifecycle (NEW - CRITICAL)
Add prominent warning section from CHAIN_LIFECYCLE_FINDINGS.md:
- Hot subscription model explanation
- Memory leak dangers with inline creation
- ✅ Safe patterns (watch_it, create outside build)
- ❌ Unsafe patterns (ValueListenableBuilder inline)
- Link to detailed lifecycle guide

### Ecosystem Integration
Rewrite to match get_it style:
- **Works independently** — Use standalone
- **Optional combinations:**
  - watch_it (automatic selector caching!)
  - get_it (register observables)
  - command_it (uses listen_it internally)
- **Remember:** flutter_it is a construction set

### Learn More (NEW)
Organized documentation links:
- **Getting Started** → listen_it.md
- **Operators** → operators/overview.md
- **Collections** → collections/introduction.md
- **Best Practices** → (lifecycle warnings)
- **API Docs** → pub.dev

### Community & Support (NEW)
- Discord link
- GitHub Issues
- GitHub Discussions

### Standard Sections
- Contributing
- License
- Footer with ecosystem branding

**Target length: ~200-220 lines** (similar to get_it's 193)

## Part 2: Extract Code Samples

Create in `/home/escamoteur/dev/flutter_it/docs/code_samples/lib/listen_it/`:

### _shared/stubs.dart
- User class (age, name)
- Product, CartItem classes
- SearchResult class
- StringIntWrapper class
- Mock API functions (callRestApi, searchApi)

### Operator Samples
- `listen_basic.dart` - listen() with cancellation
- `map_transform.dart` - map() examples
- `select_property.dart` - select() for properties
- `where_filter.dart` - where() filtering
- `chain_operators.dart` - Chaining example
- `debounce_search.dart` - debounce() for search
- `combine_latest.dart` - combineLatest()
- `merge_with.dart` - mergeWith()

### Collection Samples
- `list_notifier_basic.dart` - Basic ListNotifier
- `list_notifier_widget.dart` - TodoList with ValueListenableBuilder
- `notification_modes.dart` - Three modes compared
- `transactions.dart` - Batch updates
- `shopping_cart.dart` - Real-world MapNotifier example
- `search_viewmodel.dart` - Search with debounce + ListNotifier
- `custom_value_notifier.dart` - CustomValueNotifier modes

### Lifecycle Examples (from CHAIN_LIFECYCLE_FINDINGS.md)
- `chain_correct_pattern.dart` - ✅ Chain outside build
- `chain_incorrect_pattern.dart` - ❌ Inline creation leak (signature file)
- `chain_watch_it_safe.dart` - ✅ watch_it with caching
- `chain_disposal.dart` - Proper disposal

**Total: ~19 code sample files**

## Part 3: Update Documentation Pages

Update 12 pages in `/home/escamoteur/dev/flutter_it/docs/docs/documentation/listen_it/`:

### 1. listen_it.md (main page)
- Overview of both operators + collections
- Quick start
- When to use what
- Link to detailed guides
- **Prominent lifecycle warning box**

### 2. operators/overview.md
- Introduction to operators
- Chaining concept
- List of all operators with brief descriptions
- Links to detailed pages

### 3-6. Operator Detail Pages
- **transform.md**: map(), select() with examples
- **filter.md**: where() with examples
- **combine.md**: combineLatest(), mergeWith() with examples
- **time.md**: debounce() with examples + lifecycle warnings

### 7. collections/introduction.md
- Overview of three collection types
- Comparison table (when to use what)
- Integration with Flutter (ValueListenableBuilder)
- Integration with watch_it

### 8-10. Collection Detail Pages
- **list_notifier.md**: ListNotifier guide + examples
- **map_notifier.md**: MapNotifier guide + examples (shopping cart)
- **set_notifier.md**: SetNotifier guide + examples

### 11. collections/notification_modes.md
- CustomNotifierMode explained
- normal vs always vs manual
- When to use each mode
- Code examples

### 12. collections/transactions.md
- startTransAction/endTransAction
- Performance benefits
- Examples

## Part 4: Add Lifecycle/Best Practices Guide (NEW)

Create new page: **documentation/listen_it/best_practices.md**

Content from CHAIN_LIFECYCLE_FINDINGS.md:
- Hot subscription model explanation
- Chain object lifecycle
- Memory leak scenarios
- ✅ DO patterns
- ❌ DON'T patterns
- watch_it integration (automatic caching)
- Disposal strategies
- Circular reference explanation

Add to sidebar in config.mts.

## Implementation Order
1. Create _shared/stubs.dart
2. Extract ~15-20 code samples
3. Update package README.md (listen_it folder)
4. Update main listen_it.md doc page
5. Update 5 operator pages
6. Update 6 collection pages
7. Create best_practices.md page
8. Update sidebar config if needed
9. Verify all code compiles
10. Format all code

## Key Principles
- Match get_it README quality and structure
- **Prominent lifecycle warnings** throughout
- Links to flutter-it.dev everywhere
- "Construction set" messaging
- All code samples as separate .dart files
- VitePress includes: `<<< @/../code_samples/lib/listen_it/...`

## Reference Documents
- `/home/escamoteur/dev/flutter_it/listen_it/README.md` - Current README (source content)
- `/home/escamoteur/dev/flutter_it/listen_it/CHAIN_LIFECYCLE_FINDINGS.md` - Critical lifecycle insights
- `/home/escamoteur/dev/flutter_it/get_it/README.md` - Target structure template
- `/home/escamoteur/dev/flutter_it/docs/docs/documentation/listen_it/` - Documentation to update

## Success Criteria
- README.md matches get_it quality (~200-220 lines)
- All code samples compile with `flutter analyze`
- All documentation pages complete and comprehensive
- Lifecycle warnings prominent throughout
- "Construction set" messaging consistent
- All links working (flutter-it.dev, Discord, GitHub)
