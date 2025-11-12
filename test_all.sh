#!/bin/bash
cd /home/pingguomiaomiao/Desktop/Mochi
total=0
passed=0
failed=0

for file in test_cases/mbt/*.mbt; do
    if [ -f "$file" ]; then
        total=$((total + 1))
        basename=$(basename "$file" .mbt)
        echo "Testing: $basename"
        if moon run src/bin/main.mbt -- --typecheck "$file" > /tmp/test_${basename}.log 2>&1; then
            echo "  ✓ PASSED"
            passed=$((passed + 1))
        else
            echo "  ✗ FAILED"
            failed=$((failed + 1))
            head -5 /tmp/test_${basename}.log | grep -E "(error|Error|Parse error|Type error)" | head -3
        fi
    fi
done

echo ""
echo "Summary: $passed/$total passed, $failed failed"
