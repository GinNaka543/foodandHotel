#!/bin/bash

# Script to remove debug print statements from Swift files
# WARNING: This will modify files in place. Make sure to commit changes first!

echo "🔍 Searching for debug print statements..."

# Count total debug prints before removal
total_before=$(grep -r "print(" *.swift 2>/dev/null | wc -l)
echo "Found $total_before print statements"

# Create backup directory
mkdir -p debug_backup
echo "📁 Creating backups in debug_backup/"

# Find all Swift files and process them
find . -name "*.swift" -type f | while read file; do
    # Skip backup files
    if [[ $file == *"backup"* ]] || [[ $file == "./debug_backup"* ]]; then
        continue
    fi
    
    # Create backup
    cp "$file" "debug_backup/$(basename $file).backup"
    
    # Count prints in this file
    count=$(grep -c "print(" "$file" 2>/dev/null || echo 0)
    
    if [ $count -gt 0 ]; then
        echo "Processing $file ($count print statements)..."
        
        # Remove print statements (multiple patterns)
        # Pattern 1: Simple print statements on single line
        sed -i '' '/^[[:space:]]*print(/d' "$file"
        
        # Pattern 2: print statements with DEBUG tags
        sed -i '' '/print(".*\[DEBUG\]/d' "$file"
        sed -i '' '/print(".*\[INFO\]/d' "$file"
        sed -i '' '/print(".*\[ERROR\]/d' "$file"
        
        # Pattern 3: print statements with emoji prefixes
        sed -i '' '/print("🔥/d' "$file"
        sed -i '' '/print("❌/d' "$file"
        sed -i '' '/print("✅/d' "$file"
        sed -i '' '/print("⚠️/d' "$file"
        sed -i '' '/print("💾/d' "$file"
        sed -i '' '/print("📖/d' "$file"
        sed -i '' '/print("🔄/d' "$file"
        sed -i '' '/print("💰/d' "$file"
        sed -i '' '/print("🎬/d' "$file"
        sed -i '' '/print("🎵/d' "$file"
        
        # Pattern 4: Multi-line print statements (be careful with this)
        # This removes print statements that span multiple lines
        perl -i -0pe 's/\n\s*print\([^)]*\)//g' "$file"
    fi
done

# Count remaining prints
total_after=$(grep -r "print(" *.swift 2>/dev/null | wc -l)
removed=$((total_before - total_after))

echo "✅ Removed $removed print statements"
echo "📊 Remaining: $total_after print statements"

# Show remaining prints for manual review
if [ $total_after -gt 0 ]; then
    echo ""
    echo "⚠️  Some print statements remain and need manual review:"
    grep -n "print(" *.swift 2>/dev/null | head -20
    echo ""
    echo "Run 'grep -r \"print(\" *.swift' to see all remaining prints"
fi

echo ""
echo "🎯 Next steps:"
echo "1. Review the changes with: git diff"
echo "2. Test the app thoroughly"
echo "3. If everything works, commit the changes"
echo "4. If issues arise, restore from debug_backup/"