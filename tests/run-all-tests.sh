#!/bin/bash
# Test Runner Script for Garuda Security Suite
# Executes all test suites and generates comprehensive reports

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$SCRIPT_DIR/test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$TEST_RESULTS_DIR/test-report-$TIMESTAMP.txt"
COVERAGE_FILE="$TEST_RESULTS_DIR/coverage-report-$TIMESTAMP.txt"
SUMMARY_FILE="$TEST_RESULTS_DIR/test-summary-$TIMESTAMP.txt"

# Colors for output
declare -A COLORS=(
    ["RED"]='\033[0;31m'
    ["GREEN"]='\033[0;32m'
    ["YELLOW"]='\033[1;33m'
    ["BLUE"]='\033[0;34m'
    ["PURPLE"]='\033[0;35m'
    ["CYAN"]='\033[0;36m'
    ["NC"]='\033[0m'
)

# Test suites
TEST_SUITES=(
    "test-suite.bats:Unit Tests"
    "integration-tests.bats:Integration Tests"
    "performance-tests.bats:Performance Tests"
    "security-tests.bats:Security Tests"
)

# Initialize test results directory
mkdir -p "$TEST_RESULTS_DIR"

# Logging functions
log_info() {
    echo -e "${COLORS[BLUE]}[INFO]${COLORS[NC]} $1" | tee -a "$REPORT_FILE"
}

log_success() {
    echo -e "${COLORS[GREEN]}[SUCCESS]${COLORS[NC]} $1" | tee -a "$REPORT_FILE"
}

log_warning() {
    echo -e "${COLORS[YELLOW]}[WARNING]${COLORS[NC]} $1" | tee -a "$REPORT_FILE"
}

log_error() {
    echo -e "${COLORS[RED]}[ERROR]${COLORS[NC]} $1" | tee -a "$REPORT_FILE"
}

log_header() {
    echo -e "${COLORS[PURPLE]}=== $1 ===${COLORS[NC]}" | tee -a "$REPORT_FILE"
}

# Check dependencies
check_dependencies() {
    log_info "Checking test dependencies..."
    
    local missing_deps=()
    
    # Check BATS
    if ! command -v bats &> /dev/null; then
        missing_deps+=("bats")
    fi
    
    # Check shellcheck
    if ! command -v shellcheck &> /dev/null; then
        missing_deps+=("shellcheck")
    fi
    
    # Check basic tools
    for tool in awk grep sed find; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install missing dependencies with:"
        log_info "  sudo pacman -S ${missing_deps[*]}"
        return 1
    fi
    
    log_success "All dependencies found"
    return 0
}

# Run shellcheck on scripts
run_shellcheck() {
    log_header "Running Shellcheck Analysis"
    
    local shellcheck_results="$TEST_RESULTS_DIR/shellcheck-$TIMESTAMP.txt"
    local exit_code=0
    
    # Run shellcheck on all shell scripts
    find "$PROJECT_ROOT" -name "*.sh" -type f ! -path "*/tests/*" -exec shellcheck {} \; > "$shellcheck_results" 2>&1 || exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "Shellcheck passed - No issues found"
    else
        log_warning "Shellcheck found issues - See $shellcheck_results"
        cat "$shellcheck_results" | tee -a "$REPORT_FILE"
    fi
    
    return $exit_code
}

# Run a single test suite
run_test_suite() {
    local test_file="$1"
    local suite_name="$2"
    local results_file="$TEST_RESULTS_DIR/${test_file%.*}-$TIMESTAMP.tap"
    
    log_header "Running $suite_name"
    
    # Run BATS test suite
    if bats --formatter tap "$SCRIPT_DIR/$test_file" > "$results_file" 2>&1; then
        log_success "$suite_name completed successfully"
        return 0
    else
        log_error "$suite_name failed"
        cat "$results_file" | tee -a "$REPORT_FILE"
        return 1
    fi
}

# Parse test results
parse_test_results() {
    local results_file="$1"
    local suite_name="$2"
    
    local total_tests=$(grep -c "^ok\|^not ok" "$results_file" 2>/dev/null || echo "0")
    local passed_tests=$(grep -c "^ok" "$results_file" 2>/dev/null || echo "0")
    local failed_tests=$(grep -c "^not ok" "$results_file" 2>/dev/null || echo "0")
    local skipped_tests=$(grep -c "^ok.*# skip" "$results_file" 2>/dev/null || echo "0")
    
    echo "$suite_name:$total_tests:$passed_tests:$failed_tests:$skipped_tests"
}

# Generate test summary
generate_summary() {
    log_header "Test Summary"
    
    local total_suites=0
    local total_tests=0
    local total_passed=0
    local total_failed=0
    local total_skipped=0
    
    echo "Suite,Total,Passed,Failed,Skipped,Success Rate" > "$SUMMARY_FILE"
    
    for suite_info in "${TEST_SUITES[@]}"; do
        IFS=':' read -r test_file suite_name <<< "$suite_info"
        local results_file="$TEST_RESULTS_DIR/${test_file%.*}-$TIMESTAMP.tap"
        
        if [ -f "$results_file" ]; then
            local result=$(parse_test_results "$results_file" "$suite_name")
            IFS=':' read -r name total passed failed skipped <<< "$result"
            
            local success_rate=0
            if [ "$total" -gt 0 ]; then
                success_rate=$((passed * 100 / total))
            fi
            
            echo "$suite_name,$total,$passed,$failed,$skipped,${success_rate}%" >> "$SUMMARY_FILE"
            
            total_suites=$((total_suites + 1))
            total_tests=$((total_tests + total))
            total_passed=$((total_passed + passed))
            total_failed=$((total_failed + failed))
            total_skipped=$((total_skipped + skipped))
            
            log_info "$suite_name: $passed/$total tests passed (${success_rate}%)"
        fi
    done
    
    # Overall summary
    local overall_success_rate=0
    if [ "$total_tests" -gt 0 ]; then
        overall_success_rate=$((total_passed * 100 / total_tests))
    fi
    
    echo "" | tee -a "$REPORT_FILE"
    log_header "Overall Results"
    echo "Total Suites: $total_suites" | tee -a "$REPORT_FILE"
    echo "Total Tests: $total_tests" | tee -a "$REPORT_FILE"
    echo "Passed: $total_passed" | tee -a "$REPORT_FILE"
    echo "Failed: $total_failed" | tee -a "$REPORT_FILE"
    echo "Skipped: $total_skipped" | tee -a "$REPORT_FILE"
    echo "Success Rate: ${overall_success_rate}%" | tee -a "$REPORT_FILE"
    
    # Check if we meet coverage requirements
    if [ "$overall_success_rate" -ge 90 ]; then
        log_success "Test coverage requirement met (>= 90%)"
    else
        log_warning "Test coverage requirement not met (< 90%)"
    fi
    
    return $total_failed
}

# Generate coverage report
generate_coverage_report() {
    log_header "Generating Coverage Report"
    
    cat > "$COVERAGE_FILE" << EOF
=== Garuda Security Suite Test Coverage Report ===
Generated: $(date)
Project: $PROJECT_ROOT

=== Test Coverage Summary ===
EOF
    
    # Add summary from test results
    if [ -f "$SUMMARY_FILE" ]; then
        cat "$SUMMARY_FILE" >> "$COVERAGE_FILE"
    fi
    
    # Add detailed test results
    echo "" >> "$COVERAGE_FILE"
    echo "=== Detailed Test Results ===" >> "$COVERAGE_FILE"
    
    for suite_info in "${TEST_SUITES[@]}"; do
        IFS=':' read -r test_file suite_name <<< "$suite_info"
        local results_file="$TEST_RESULTS_DIR/${test_file%.*}-$TIMESTAMP.tap"
        
        if [ -f "$results_file" ]; then
            echo "" >> "$COVERAGE_FILE"
            echo "--- $suite_name ---" >> "$COVERAGE_FILE"
            cat "$results_file" >> "$COVERAGE_FILE"
        fi
    done
    
    # Add shellcheck results if available
    local shellcheck_results="$TEST_RESULTS_DIR/shellcheck-$TIMESTAMP.txt"
    if [ -f "$shellcheck_results" ]; then
        echo "" >> "$COVERAGE_FILE"
        echo "--- Shellcheck Analysis ---" >> "$COVERAGE_FILE"
        cat "$shellcheck_results" >> "$COVERAGE_FILE"
    fi
    
    log_success "Coverage report generated: $COVERAGE_FILE"
}

# Generate HTML report
generate_html_report() {
    local html_file="$TEST_RESULTS_DIR/test-report-$TIMESTAMP.html"
    
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Garuda Security Suite Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .suite { margin: 20px 0; border: 1px solid #ddd; padding: 15px; border-radius: 5px; }
        .success { color: green; }
        .failure { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .code { background-color: #f5f5f5; padding: 10px; border-radius: 3px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Garuda Security Suite Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Project: $PROJECT_ROOT</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <p>This report contains the results of comprehensive testing for the Garuda Security Suite.</p>
    </div>
EOF
    
    # Add summary table if available
    if [ -f "$SUMMARY_FILE" ]; then
        cat >> "$html_file" << EOF
    <div class="summary">
        <h2>Test Results Summary</h2>
        <table>
            <tr><th>Suite</th><th>Total</th><th>Passed</th><th>Failed</th><th>Skipped</th><th>Success Rate</th></tr>
EOF
        
        # Skip header line
        tail -n +2 "$SUMMARY_FILE" | while IFS=',' read -r suite total passed failed skipped rate; do
            local row_class="success"
            if [ "$failed" -gt 0 ]; then
                row_class="failure"
            elif [ "$skipped" -gt 0 ]; then
                row_class="warning"
            fi
            
            cat >> "$html_file" << EOF
            <tr class="$row_class">
                <td>$suite</td><td>$total</td><td>$passed</td><td>$failed</td><td>$skipped</td><td>$rate</td>
            </tr>
EOF
        done
        
        cat >> "$html_file" << EOF
        </table>
    </div>
EOF
    fi
    
    # Add detailed results
    for suite_info in "${TEST_SUITES[@]}"; do
        IFS=':' read -r test_file suite_name <<< "$suite_info"
        local results_file="$TEST_RESULTS_DIR/${test_file%.*}-$TIMESTAMP.tap"
        
        if [ -f "$results_file" ]; then
            cat >> "$html_file" << EOF
    <div class="suite">
        <h3>$suite_name</h3>
        <div class="code">
            <pre>$(cat "$results_file")</pre>
        </div>
    </div>
EOF
        fi
    done
    
    cat >> "$html_file" << EOF
</body>
</html>
EOF
    
    log_success "HTML report generated: $html_file"
}

# Main execution
main() {
    log_header "Garuda Security Suite Test Runner"
    log_info "Starting comprehensive test execution..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Test results directory: $TEST_RESULTS_DIR"
    
    # Initialize report file
    cat > "$REPORT_FILE" << EOF
=== Garuda Security Suite Test Report ===
Generated: $(date)
Project: $PROJECT_ROOT
Test Runner: $0

EOF
    
    # Check dependencies
    if ! check_dependencies; then
        log_error "Dependency check failed - Exiting"
        exit 1
    fi
    
    # Run shellcheck
    local shellcheck_exit=0
    if ! run_shellcheck; then
        shellcheck_exit=1
    fi
    
    # Run test suites
    local test_exit=0
    for suite_info in "${TEST_SUITES[@]}"; do
        IFS=':' read -r test_file suite_name <<< "$suite_info"
        
        if ! run_test_suite "$test_file" "$suite_name"; then
            test_exit=1
        fi
    done
    
    # Generate reports
    generate_summary
    generate_coverage_report
    generate_html_report
    
    # Final status
    log_header "Test Execution Complete"
    
    if [ $test_exit -eq 0 ] && [ $shellcheck_exit -eq 0 ]; then
        log_success "All tests passed successfully!"
        log_info "Reports available in: $TEST_RESULTS_DIR"
        exit 0
    else
        log_error "Some tests failed - Check reports for details"
        log_info "Reports available in: $TEST_RESULTS_DIR"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Garuda Security Suite Test Runner"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --shellcheck    Run only shellcheck analysis"
        echo "  --unit          Run only unit tests"
        echo "  --integration   Run only integration tests"
        echo "  --performance   Run only performance tests"
        echo "  --security      Run only security tests"
        echo ""
        echo "If no options are specified, all tests will be run."
        exit 0
        ;;
    --shellcheck)
        check_dependencies || exit 1
        run_shellcheck || exit 1
        exit 0
        ;;
    --unit)
        check_dependencies || exit 1
        run_test_suite "test-suite.bats" "Unit Tests" || exit 1
        exit 0
        ;;
    --integration)
        check_dependencies || exit 1
        run_test_suite "integration-tests.bats" "Integration Tests" || exit 1
        exit 0
        ;;
    --performance)
        check_dependencies || exit 1
        run_test_suite "performance-tests.bats" "Performance Tests" || exit 1
        exit 0
        ;;
    --security)
        check_dependencies || exit 1
        run_test_suite "security-tests.bats" "Security Tests" || exit 1
        exit 0
        ;;
    "")
        # Run all tests
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac