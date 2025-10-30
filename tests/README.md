# Garuda Security Suite Testing Framework

This comprehensive testing framework provides complete validation for the Garuda Security Suite, ensuring all Phase 1 implementation requirements are met with high test coverage and security validation.

## Overview

The testing framework includes:

- **Unit Tests**: Individual component testing
- **Integration Tests**: End-to-end workflow testing
- **Performance Tests**: Resource usage and benchmarking
- **Security Tests**: Vulnerability and security validation
- **Test Automation**: Complete test execution and reporting

## Quick Start

### 1. Setup Test Environment

```bash
# Run the test environment setup script
./tests/setup-test-env.sh

# Or skip security tools installation (use mocks only)
./tests/setup-test-env.sh --no-security-tools
```

### 2. Run All Tests

```bash
# Source test configuration
source tests/test-config.env

# Run all test suites
./tests/run-all-tests.sh
```

### 3. Run Specific Test Suites

```bash
# Run only unit tests
./tests/run-all-tests.sh --unit

# Run only integration tests
./tests/run-all-tests.sh --integration

# Run only performance tests
./tests/run-all-tests.sh --performance

# Run only security tests
./tests/run-all-tests.sh --security

# Run only shellcheck analysis
./tests/run-all-tests.sh --shellcheck
```

## Test Suites

### Unit Tests (`tests/test-suite.bats`)

Tests individual components and functions:

- Path resolution for any user
- Systemd service generation with dynamic paths
- Security scanner functionality (EICAR detection)
- Error handling and logging
- Sudo wrapper security (blocks dangerous commands)
- Input validation (blocks malicious input)

### Integration Tests (`tests/integration-tests.bats`)

Tests complete workflows:

- Complete daily scan workflow
- Complete setup workflow with custom user
- Error recovery during scan failure
- Configuration validation

### Performance Tests (`tests/performance-tests.bats`)

Tests resource usage and performance:

- Memory usage stays within limits (<500MB)
- Disk space usage is reasonable (<10MB logs)
- Scan completion within expected timeframes
- Concurrent scan performance
- Resource cleanup after scan completion

### Security Tests (`tests/security-tests.bats`)

Tests security vulnerabilities:

- No hardcoded credentials in scripts
- Proper file permissions are set
- Sudo operations are properly audited
- Input validation prevents injection attacks
- Path traversal attacks are blocked
- Command injection attacks are blocked

## Test Requirements

### Dependencies

The testing framework requires:

- **BATS** (Bash Automated Testing System)
- **Shellcheck** (Static analysis for shell scripts)
- **Core utilities**: awk, grep, sed, find

### Security Tools (Optional)

For full functionality testing:

- **ClamAV** (Antivirus scanner)
- **Rkhunter** (Rootkit detection)
- **Chkrootkit** (Alternative rootkit scanner)
- **Lynis** (Security auditing)

If security tools are not installed, the framework will use mock implementations for testing.

## Test Coverage

The framework aims for:

- **>90% overall test coverage**
- **100% coverage for critical security functions**
- **100% coverage for error handling**
- **Comprehensive security vulnerability testing**

## Test Reports

After running tests, comprehensive reports are generated in `tests/test-results/`:

- **test-report-*.txt**: Detailed test results
- **coverage-report-*.txt**: Coverage analysis
- **test-summary-*.csv**: Summary statistics
- **test-report-*.html**: Interactive HTML report

## Test Environment

### Mock Tools

The framework includes mock implementations of security tools for testing:

- `tests/mock-bin/clamscan`: Mock ClamAV scanner
- `tests/mock-bin/rkhunter`: Mock Rkhunter scanner
- `tests/mock-bin/freshclam`: Mock virus definition updater
- `tests/mock-bin/chkrootkit`: Mock Chkrootkit scanner
- `tests/mock-bin/lynis`: Mock Lynis auditor
- `tests/mock-bin/systemctl`: Mock systemd controller
- `tests/mock-bin/loginctl`: Mock login controller
- `tests/mock-bin/notify-send`: Mock notification sender

### Test Isolation

Each test runs in an isolated environment:

- Temporary test directories
- Mock configuration files
- Isolated environment variables
- Automatic cleanup after tests

## Writing New Tests

### Test Structure

```bash
#!/usr/bin/env bats
# Test file description

load "test-helper"

setup() {
    setup_test_environment
    mock_external_commands
}

teardown() {
    cleanup_test_environment
}

@test "test description" {
    # Test implementation
    run command_to_test
    
    [ "$status" -eq 0 ]  # Check exit code
    [ "$output" = "expected" ]  # Check output
}
```

### Test Helper Functions

- `setup_test_environment()`: Create isolated test environment
- `cleanup_test_environment()`: Clean up test resources
- `mock_external_commands()`: Create mock command implementations
- `start_memory_monitor()`: Start memory usage monitoring
- `stop_memory_monitor()`: Stop memory monitoring
- `get_max_memory_usage()`: Get maximum memory usage

### Assertions

Use BATS built-in assertions:

- `[ "$status" -eq 0 ]`: Check exit code
- `[ "$output" = "expected" ]`: Check output
- `[ -f "file" ]`: Check file exists
- `grep -q "pattern" "file"`: Check file content

## Continuous Integration

### GitHub Actions

The testing framework is designed for CI/CD integration:

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup Test Environment
      run: ./tests/setup-test-env.sh --no-security-tools
    - name: Run Tests
      run: ./tests/run-all-tests.sh
    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: tests/test-results/
```

### Quality Gates

The framework enforces quality gates:

- **Code Quality**: Shellcheck passes with zero errors
- **Test Coverage**: >90% coverage required
- **Security**: No critical security vulnerabilities
- **Performance**: Memory <500MB, logs <10MB/day

## Troubleshooting

### Common Issues

1. **BATS not found**
   ```bash
   # Install BATS
   sudo pacman -S bats  # Arch/Garuda
   # Or install from GitHub
   git clone https://github.com/bats-core/bats-core.git
   cd bats-core && sudo ./install.sh /usr/local
   ```

2. **Shellcheck not found**
   ```bash
   # Install Shellcheck
   sudo pacman -S shellcheck  # Arch/Garuda
   sudo apt-get install shellcheck  # Ubuntu/Debian
   ```

3. **Permission denied errors**
   ```bash
   # Make scripts executable
   chmod +x tests/*.sh tests/*.bats
   ```

4. **Test environment conflicts**
   ```bash
   # Clean test environment
   rm -rf /tmp/garuda-security-test-*
   ```

### Debug Mode

Enable debug output:

```bash
# Enable BATS debug
export BATS_DEBUG=1

# Enable test debug
export TEST_DEBUG=1

# Run tests with debug
./tests/run-all-tests.sh --unit
```

## Contributing

When adding new tests:

1. Follow the existing test structure
2. Use descriptive test names
3. Test both success and failure cases
4. Include security considerations
5. Add performance validation where relevant
6. Update documentation

## License

This testing framework is part of the Garuda Security Suite project and follows the same license terms.