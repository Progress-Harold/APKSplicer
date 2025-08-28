# Aurora README Sync Workflow

## 📋 Workflow Rule

**Every time we complete a task in `aurora_progress.md`, we must update the README.md with the latest progress and achievements.**

## 🔄 Automated Sync Process

### 1. Manual Sync Command

Run the sync script manually after updating progress:

```bash
./Scripts/sync-readme-progress.sh
```

### 2. What Gets Synced

The script automatically updates:

- **Overall Progress Percentage** - Extracted from `aurora_progress.md`
- **Current Phase** - Current development phase information
- **Production Status** - Dynamically generated based on completion percentage
- **Recent Achievements** - Latest completed tasks with dates
- **Progress Badges** - Updates percentage in feature descriptions

### 3. Progress Status Mapping

| Progress | Status | Description |
|----------|--------|-------------|
| 0-24% | **Foundation** | Basic architecture and setup |
| 25-49% | **Early Development** | Core features being built |
| 50-74% | **Advanced Development** | Major features completed |
| 75-100% | **Production-Ready** | Ready for release |

## 🛠️ Implementation Details

### Script Location
- **Script**: `Scripts/sync-readme-progress.sh`
- **Source**: `APKSplicer/Docs/aurora_progress.md`
- **Target**: `README.md`

### What the Script Does

1. **Extracts Progress**: Parses the "Overall Progress: XX%" line
2. **Gets Current Phase**: Finds the current development phase
3. **Updates Status**: Dynamically generates production-ready status
4. **Syncs Achievements**: Updates recent achievements section
5. **Preserves Structure**: Maintains README formatting and content

### Git Integration

The script can be integrated with Git hooks for automatic updates:

```bash
# Add to .git/hooks/pre-commit
#!/bin/bash
./Scripts/sync-readme-progress.sh
git add README.md
```

## 📝 Usage Workflow

### When Completing Tasks

1. **Update Progress File**: Mark tasks as complete in `aurora_progress.md`
2. **Update Overall Progress**: Change the percentage if significant milestone reached
3. **Run Sync Script**: `./Scripts/sync-readme-progress.sh`
4. **Commit Changes**: Include both progress and README updates
5. **Push to GitHub**: Share updated progress with team

### Example Commit Workflow

```bash
# 1. Update progress file
vim APKSplicer/Docs/aurora_progress.md

# 2. Sync README automatically
./Scripts/sync-readme-progress.sh

# 3. Commit both files
git add APKSplicer/Docs/aurora_progress.md README.md
git commit -m "🎯 Complete input mapping system (AUR-E-001)

- Implemented keyboard to touch translation
- Added JSON configuration profiles  
- Updated progress to 60%"

# 4. Push to repository
git push origin main
```

## 🎯 Benefits

- **Consistency**: README always reflects current progress
- **Automation**: Reduces manual maintenance overhead
- **Professional**: Keeps public documentation up-to-date
- **Transparency**: Shows real-time development progress
- **Accuracy**: Eliminates sync lag between internal and public docs

## 🔧 Customization

The script can be modified to:

- Change progress status thresholds
- Update different README sections
- Add more detailed achievement formatting
- Include automatic changelog generation
- Sync with GitHub project boards

---

**Remember**: Always run the sync script after updating progress to maintain consistency!
