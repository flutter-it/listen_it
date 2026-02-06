# Claude Code Skills for listen_it

This directory contains **Claude Code skill files** that help AI assistants (like Claude Code, Cursor, GitHub Copilot) generate correct listen_it code efficiently.

## What are Skills?

Skills are concise reference guides optimized for AI consumption. They contain:
- Critical rules and constraints
- Common usage patterns
- Anti-patterns with corrections
- Integration examples

**Note**: These are NOT replacements for comprehensive documentation. For detailed guides, see https://flutter-it.dev/documentation/listen_it/

## Available Skills

This directory includes:

1. **`listen_it-expert.md`** - ValueListenable operators, reactive collections, patterns
2. **`flutter-architecture-expert.md`** - High-level app architecture guidance

**Note**: For the ecosystem overview, see `/skills/flutter_it.md` in the monorepo root.

## Installation

To use these skills with Claude Code:

### Option 1: Copy to Global Skills Directory (Recommended)

```bash
# Copy all skills to your global Claude Code skills directory
cp skills/*.md ~/.claude/skills/
```

### Option 2: Symlink (Auto-updates when package updates)

```bash
# Create symlinks (Linux/Mac)
ln -s $(pwd)/skills/listen_it-expert.md ~/.claude/skills/listen_it-expert.md
ln -s $(pwd)/skills/flutter-architecture-expert.md ~/.claude/skills/flutter-architecture-expert.md
```

### Option 3: Manual Copy (Windows)

```powershell
# Copy files manually
copy skills\*.md %USERPROFILE%\.claude\skills\
```

## Using the Skills

Once installed, Claude Code will automatically have access to these skills when working on Flutter projects.

**For other AI assistants**:
- **Cursor**: Copy to project root or reference in `.cursorrules`
- **GitHub Copilot**: Copy to `.github/copilot-instructions.md`

## Verification

After installation, you can verify by asking Claude Code:

```
Can you help me debounce a search field with listen_it?
```

Claude should reference the skill and provide correct operator patterns.

## Contents Overview

### listen_it-expert.md (~1000 tokens)

Covers:
- Core operators (map, where, debounce, throttle, select)
- Combining ValueListenables (combineLatest, merge)
- **CRITICAL**: Operators return NEW objects (must capture result)
- **CRITICAL**: Use listen() instead of addListener()
- Reactive collections (ListNotifier, MapNotifier, SetNotifier)
- Operator chaining patterns
- Common use cases (search, validation, computed properties)
- Integration with command_it and watch_it
- Common anti-patterns

### flutter-architecture-expert.md (~800 tokens)

Covers:
- Using listen_it in app architecture
- Reactive patterns with ValueListenable
- State management integration

## Why listen_it Skills Are Important

listen_it has **critical patterns** that can cause bugs if missed:

1. **Operators return NEW objects** - Must capture: `final doubled = source.map(...)`
2. **Use listen() instead of addListener()** - Better API with automatic cleanup
3. **Collections auto-notify** - ListNotifier/MapNotifier call notifyListeners() on mutations
4. **Chaining creates pipelines** - Each operator returns new ValueListenable

## Documentation Links

- **Comprehensive docs**: https://flutter-it.dev/documentation/listen_it/
- **Package README**: https://pub.dev/packages/listen_it
- **GitHub**: https://github.com/escamoteur/listen_it
- **Discord**: https://discord.gg/ZHYHYCM38h

## Contributing

Found an issue or have suggestions for improving these skills?
- Open an issue on GitHub
- Join the Discord community
- Submit a PR with improvements

---

**Note**: These skills are designed for AI consumption. For human-readable documentation, please visit https://flutter-it.dev
