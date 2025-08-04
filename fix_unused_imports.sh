#!/bin/bash

# Run flutter analyze and extract unused import warnings
flutter analyze 2>&1 | grep "warning • Unused import:" > unused_imports.txt

# Process each unused import
while IFS= read -r line; do
    # Extract file path and import line
    if [[ $line =~ "warning • Unused import: '(.+)' • (.+):([0-9]+):" ]]; then
        import="${BASH_REMATCH[1]}"
        file="${BASH_REMATCH[2]}"
        line_num="${BASH_REMATCH[3]}"
        
        echo "Fixing unused import '$import' in $file at line $line_num"
        
        # Use sed to remove the import line
        sed -i "${line_num}d" "$file"
    fi
done < unused_imports.txt

rm unused_imports.txt
echo "Done fixing unused imports!"