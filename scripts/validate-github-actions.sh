#!/bin/bash

# Diagnostic script to validate GitHub Actions versions
# This script checks for deprecated actions and suggests updates

echo "=== GitHub Actions Validation Diagnostic ==="
echo "Date: $(date)"
echo ""

# Check current workflow file
WORKFLOW_FILE=".github/workflows/test.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "ERROR: Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "Analyzing workflow: $WORKFLOW_FILE"
echo ""

# Check for deprecated actions
echo "=== Checking for deprecated actions ==="

# Check upload-artifact
if grep -q "actions/upload-artifact@v3" "$WORKFLOW_FILE"; then
    echo "❌ DEPRECATED: actions/upload-artifact@v3 found"
    echo "   - Deprecated since: April 16, 2024"
    echo "   - Should update to: actions/upload-artifact@v4"
    echo "   - Line: $(grep -n "actions/upload-artifact@v3" "$WORKFLOW_FILE")"
else
    echo "✅ OK: No deprecated upload-artifact@v3 found"
fi

# Check checkout action
if grep -q "actions/checkout@v3" "$WORKFLOW_FILE"; then
    echo "⚠️  WARNING: actions/checkout@v3 found"
    echo "   - May be deprecated, consider updating to v4"
    echo "   - Line: $(grep -n "actions/checkout@v3" "$WORKFLOW_FILE")"
else
    echo "✅ OK: No potentially deprecated checkout@v3 found"
fi

echo ""

# Check for other common deprecated patterns
echo "=== Checking for other deprecated patterns ==="

# Check for setup-node
if grep -q "actions/setup-node@v3" "$WORKFLOW_FILE"; then
    echo "⚠️  WARNING: actions/setup-node@v3 found"
    echo "   - Consider updating to v4"
    echo "   - Line: $(grep -n "actions/setup-node@v3" "$WORKFLOW_FILE")"
fi

# Check for setup-python
if grep -q "actions/setup-python@v4" "$WORKFLOW_FILE"; then
    echo "⚠️  WARNING: actions/setup-python@v4 found"
    echo "   - Consider updating to v5"
    echo "   - Line: $(grep -n "actions/setup-python@v4" "$WORKFLOW_FILE")"
fi

echo ""

# Show current action versions
echo "=== Current action versions in workflow ==="
grep -n "uses.*@" "$WORKFLOW_FILE" | while read line; do
    echo "   $line"
done

echo ""

# Recommendations
echo "=== Recommendations ==="
echo "1. Update actions/upload-artifact@v3 to @v4"
echo "2. Consider updating actions/checkout@v3 to @v4"
echo "3. Use specific version tags (e.g., @v4.0.0) for better stability"
echo "4. Test workflow after updates"

echo ""
echo "=== Diagnostic complete ==="