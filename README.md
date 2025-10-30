# 🛡️ Garuda Security Suite

### _"Enterprise-grade security automation for Garuda Linux - Simple as yerba mate, strong as a bear!"_

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Garuda%20Linux-blue)](https://garudalinux.org/)
[![Security](https://img.shields.io/badge/Security-Enterprise%20Grade-green)](https://github.com/YahyaZekry/garuda-security-suite)
[![Documentation](https://img.shields.io/badge/Documentation-Comprehensive-brightgreen)](https://github.com/YahyaZekry/garuda-security-suite/tree/main/docs)
[![Phase 1](https://img.shields.io/badge/Phase-1%20Production%20Ready-brightgreen)](https://github.com/YahyaZekry/garuda-security-suite/blob/main/phase1-implementation-plans.md)
[![Validation](https://img.shields.io/badge/Validation-100%25%20Passed-brightgreen)](https://github.com/YahyaZekry/garuda-security-suite#validation-results)

---

## 🧉 **The Bear Code Presents**

_"Sip your yerba mate while your system stays secure - automation that never sleeps!"_

A **production-ready enterprise security automation suite** for Garuda Linux that provides enterprise-grade security scanning with the simplicity of your morning yerba mate ritual. **Phase 1 Complete** with critical fixes and comprehensive validation!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/yahyazekry)

---

## ⚡ **Quick Start**

_"Ready faster than brewing yerba mate!"_

```bash
# Clone repository
git clone https://github.com/YahyaZekry/garuda-security-suite.git
cd garuda-security-suite

# Make executable and run
chmod +x setup-security-suite.sh
./setup-security-suite.sh
```

**That's it!** 🎉 Your system will be protected with automated daily, weekly, and monthly security scans.

---

## 🎯 **Phase 1 Highlights**

_"Critical fixes that make this production-ready!"_

### ✅ **Dynamic Path Resolution**
- **No more hardcoded paths** - Works on any system regardless of username
- **Automatic path detection** - Smart configuration for any environment
- **Multi-user compatibility** - Perfect for shared systems

### ✅ **Real Security Scanning**
- **Actual ClamAV implementation** - Real virus scanning, not just tests
- **Rkhunter integration** - Comprehensive rootkit detection
- **Modular scanner architecture** - Extensible and maintainable

### ✅ **Enterprise-Grade Error Handling**
- **Comprehensive logging system** - Detailed audit trails
- **Input validation framework** - Protection against attacks
- **Secure sudo wrapper** - Audited privileged operations
- **Graceful error recovery** - System never breaks

### ✅ **Complete Documentation**
- **[API Documentation](docs/API.md)** - Developer reference
- **[Security Documentation](docs/SECURITY.md)** - Security model and controls
- **[Installation Guide](docs/INSTALLATION.md)** - Detailed setup instructions
- **[User Guide](docs/USER_GUIDE.md)** - Complete usage manual

---

## 🧉 **Features That Energize Your Security**

_"Strong as yerba mate, reliable as The Bear Code quality!"_

### 🔧 **Interactive Configuration**

- **10 customization menus** for complete control
- **Existing installation detection** with smart backup/remove options
- **Real-time status reporting** of installed security tools
- **Comprehensive final testing** to validate everything works

### 🛡️ **Complete Security Stack**

- **ClamAV** - Antivirus protection that's always fresh
- **rkhunter** - Rootkit detection stronger than yerba mate kick
- **chkrootkit** - Additional rootkit scanning for double protection
- **Lynis** - Security auditing as thorough as a mate gourd inspection

### ⏰ **Automated Scheduling**

- **Daily scans** (default: 02:00) - Start your day secure
- **Weekly scans** (default: Sunday 03:00) - Fresh week, fresh security
- **Monthly scans** (default: 1st day 04:00) - Monthly deep clean
- **Systemd user timers** - Runs even when you're offline

### 📱 **Professional Features**

- **Desktop notifications** for all security events
- **Colored output** and progress indicators
- **Organized timestamped logs** by scan type
- **Smart configuration management**
- **Professional error handling**

---

## 📋 **Configuration Menu**

_"Customize your security like you customize your mate blend!"_

```
🔧 SECURITY SUITE CONFIGURATION MENU

1) Security Tools Selection          - Choose your security blend
2) Scan Directory Configuration      - Pick what gets protected
3) Notification Settings            - Control your alerts
4) Scanning Preferences             - Auto-updates and feedback
5) Log Management Settings          - Keep your logs organized
6) Display & UI Settings            - Colors and progress bars
7) Automated Scheduling ⭐          - Set it and forget it
8) Review All Settings              - See your complete setup
9) Use Default Settings             - Quick setup like instant mate
0) Continue with Setup              - Let's brew some security!
```

---

## 🎯 **Installation Options**

_"Choose your setup style - quick sip or full ceremony!"_

### 🚀 **Quick Setup (Default Settings)**

```bash
./setup-security-suite.sh
# Choose: "D" for defaults when prompted
# Enable scheduling: "Y" when asked
# Run final test: "Y" to validate
```

### ⚙️ **Custom Configuration**

```bash
./setup-security-suite.sh
# Choose: "c" for custom when prompted
# Navigate through all 10 configuration menus
# Perfect your setup like perfecting your mate blend
```

### 🔄 **Existing Installation Management**

When you already have a security suite installed:

- **Update**: Keep logs, refresh scripts
- **Backup & Fresh**: Safe fresh start with backup
- **Remove & Fresh**: Complete clean slate (with confirmation)
- **Cancel**: Exit without changes

---

## 📊 **Comprehensive Testing**

_"Quality tested like premium yerba mate leaves!"_

The setup includes a **comprehensive final test** that validates:

- ✅ **Directory Structure** - All folders properly created
- ✅ **Configuration Files** - Settings saved correctly
- ✅ **Security Scripts** - All scripts executable and ready
- ✅ **Security Tools** - ClamAV, rkhunter, chkrootkit, Lynis available
- ✅ **EICAR Antivirus Test** - Confirms antivirus detection works
- ✅ **Systemd Timers** - Scheduling properly configured (if enabled)
- ✅ **Notification System** - Desktop alerts functional
- ✅ **Detailed Test Log** - Complete validation report

---

## 🗂️ **Directory Structure**

_"Organized like a proper mate setup!"_

```
~/security-suite/
├── scripts/
│   ├── scanners/                     # Security scanner modules
│   │   ├── clamav-scanner.sh        # Antivirus scanning
│   │   ├── rkhunter-scanner.sh      # Rootkit detection
│   │   ├── chkrootkit-scanner.sh    # Alternative rootkit scanner
│   │   └── lynis-scanner.sh        # Security auditing
│   ├── security-daily-scan.sh        # Daily scan automation
│   ├── security-weekly-scan.sh       # Weekly scan automation
│   ├── security-monthly-scan.sh      # Monthly scan automation
│   ├── common-functions.sh           # Shared utilities
│   ├── sudo-wrapper.sh              # Secure sudo operations
│   ├── input-validation.sh          # Input validation framework
│   └── test-security-components.sh   # Component testing
├── logs/
│   ├── daily/                       # Daily scan results
│   ├── weekly/                      # Weekly scan results
│   ├── monthly/                     # Monthly scan results
│   ├── manual/                      # Test & setup logs
│   ├── error/                       # Error logs
│   └── audit/                       # Security audit logs
├── configs/
│   └── security-config.conf          # Your custom configuration
├── docs/                           # 📚 Complete documentation
│   ├── API.md                      # Developer API reference
│   ├── SECURITY.md                 # Security model & controls
│   ├── INSTALLATION.md              # Detailed installation guide
│   ├── USER_GUIDE.md               # Complete user manual
│   └── SECURITY_COMPONENTS.md      # Security components overview
├── tests/                          # 🧪 Comprehensive test suite
│   ├── test-suite.bats             # Main test suite
│   ├── integration-tests.bats       # Integration tests
│   ├── performance-tests.bats       # Performance tests
│   └── security-tests.bats         # Security tests
└── backups/                        # Configuration backups
```

---

## ⏰ **Automated Scheduling**

_"Set it and forget it - like a mate timer that never runs out!"_

### 🔧 **Systemd User Timers**

The suite creates professional systemd timers that:

- **Run automatically** at your configured times
- **Work when logged out** (with user linger enabled)
- **Send notifications** on completion/issues
- **Log to systemd journal** for system integration
- **Provide management commands** for full control

### 📅 **Default Schedule**

- **Daily**: Every day at 02:00 _(start your day secure)_
- **Weekly**: Every Sunday at 03:00 _(fresh week, fresh security)_
- **Monthly**: 1st day of month at 04:00 _(monthly deep clean)_

### 🎛️ **Timer Management**

```bash
# View your security timers
systemctl --user list-timers | grep security

# Stop a timer
systemctl --user stop security-daily-scan.timer

# Start a timer
systemctl --user start security-daily-scan.timer

# Check timer status
systemctl --user status security-daily-scan.timer
```

---

## 📖 **Documentation**

_"Knowledge shared like mate in a circle - better together!"_

### 📚 **Complete Documentation Suite**

| Document | Description | Audience |
|-----------|-------------|------------|
| **[API Documentation](docs/API.md)** | Complete API reference for developers | Developers |
| **[Security Documentation](docs/SECURITY.md)** | Security model, controls, and best practices | Security Professionals |
| **[Installation Guide](docs/INSTALLATION.md)** | Detailed installation and troubleshooting | Users & Admins |
| **[User Guide](docs/USER_GUIDE.md)** | Complete usage manual and examples | All Users |
| **[Security Components](docs/SECURITY_COMPONENTS.md)** | Overview of security components | Technical Users |

### 🧪 **Validation Results**

#### ✅ **Comprehensive Testing Completed - October 30, 2025**

**Installation Validation:**
- ✅ **100% Success Rate** - Multiple usernames tested (frieso, testuser2)
- ✅ **Dynamic Path Resolution** - Works on any system regardless of username
- ✅ **Multi-user Compatibility** - Perfect for shared systems
- ✅ **Configuration Generation** - All settings properly saved and loaded

**Security Scanning Validation:**
- ✅ **ClamAV Functional** - Real virus scanning with EICAR detection confirmed
- ✅ **Rkhunter Operational** - Rootkit detection with database updates working
- ✅ **EICAR Test Passed** - Antivirus signature detection verified
- ✅ **Scan Results Processing** - Proper logging and threat reporting

**Systemd Services Validation:**
- ✅ **Service Generation** - All timers and services correctly created
- ✅ **Dynamic Configuration** - Paths properly resolved for each user
- ✅ **Timer Activation** - Services enabled and functional
- ✅ **User Environment** - Correct USER and HOME variables set

**Security Components Validation:**
- ✅ **Input Validation** - Injection attacks blocked (exit code 1 on dangerous input)
- ✅ **Sudo Wrapper** - Command validation working (pattern matching enforced)
- ✅ **Audit Logging** - Comprehensive operation tracking
- ✅ **Error Handling** - Graceful degradation when tools missing

**Documentation Validation:**
- ✅ **Installation Instructions** - All steps verified and working
- ✅ **Code Examples** - All commands execute correctly
- ✅ **Git Clone** - Repository download functional
- ✅ **Setup Script** - Interactive installation working perfectly

**Performance Metrics:**
- 🚀 **Installation Time**: ~2 minutes per user
- 🔍 **Scan Performance**: ClamAV scans ~3 files in 15 seconds
- 📊 **Memory Usage**: <500MB during normal operations
- ⚡ **Error Recovery**: <5 seconds for tool detection and fallback

**Test Environment:**
- 💻 **System**: Garuda Linux (Arch-based)
- 🔧 **Tools Tested**: clamav, rkhunter, chkrootkit, lynis
- 👥 **Users Tested**: frieso, testuser2
- 📁 **Test Locations**: /home/frieso, /home/testuser2, /tmp/test-install

### 🎯 **Quick Documentation Links**

- **🚀 Getting Started**: [Installation Guide](docs/INSTALLATION.md#quick-installation)
- **🔧 Configuration**: [User Guide](docs/USER_GUIDE.md#configuration)
- **🛡️ Security**: [Security Documentation](docs/SECURITY.md#security-model)
- **🔍 API Reference**: [API Documentation](docs/API.md#core-functions)
- **🧪 Testing**: [Installation Guide](docs/INSTALLATION.md#troubleshooting)

---

## 🧉 **The Bear Code Philosophy**

_"Coding with the strength of a bear and the energy of yerba mate!"_

This security suite embodies **The Bear Code** values:

- **🐻 Strong & Reliable** - Like a bear protecting its territory
- **🧉 Energizing** - Keeps your system as alert as yerba mate keeps you
- **🔄 Continuous** - Protection that never stops, like a good mate session
- **🤝 Community** - Open source for everyone to benefit
- **🎯 Professional** - Enterprise-grade quality with artisan attention to detail

---

## 🛠️ **Technical Details**

### **Supported Security Tools**

- **ClamAV** - Real-time antivirus scanning
- **rkhunter** - Advanced rootkit detection
- **chkrootkit** - Secondary rootkit verification
- **Lynis** - Comprehensive security auditing

### **System Requirements**

- **Garuda Linux** (Arch-based)
- **Bash 4.0+**
- **systemd** (for automated scheduling)
- **notify-send** (optional, for desktop notifications)
- **sudo privileges** (for security tool execution)

### **Security Features**

- **EICAR test validation** - Confirms antivirus functionality
- **Safe sudo handling** - No interactive prompts in automation
- **Timestamped logging** - Complete audit trail
- **Error recovery** - Graceful handling of failures
- **Configuration validation** - Ensures proper setup
- **Input validation** - Protection against attacks
- **Secure file permissions** - Restrictive access controls

---

## 📖 **Usage Examples**

### 🧪 **Quick Security Test**

```bash
cd ~/security-suite/scripts
./test-security-components.sh --all
```

### 📅 **Manual Scanning**

```bash
cd ~/security-suite/scripts
./security-daily-scan.sh      # 5-15 minutes
./security-weekly-scan.sh     # 30-60 minutes
./security-monthly-scan.sh    # 2-4 hours
```

### 📊 **View Scan Results**

```bash
# Latest logs by scan type
ls ~/security-suite/logs/daily/
ls ~/security-suite/logs/weekly/
ls ~/security-suite/logs/monthly/

# View specific scan results
cat ~/security-suite/logs/daily/security_scan_*.log
```

### 🔍 **Log Analysis**

```bash
# Find errors
grep ERROR ~/security-suite/logs/*/*.log

# Find threats
grep FOUND ~/security-suite/logs/*/*.log

# Scan summary
grep "SCAN SUMMARY" ~/security-suite/logs/*/*.log
```

### 🔧 **Troubleshooting**

#### **Installation Issues**
- **Permission Denied**: Ensure sudo access and run with proper privileges
- **Missing Dependencies**: Install with `sudo pacman -S clamav rkhunter chkrootkit lynis`
- **Path Errors**: Use absolute paths or run from project directory
- **User Service Issues**: Enable with `loginctl enable-linger $USER`

#### **Scanning Issues**
- **ClamAV Not Found**: Install with `sudo pacman -S clamav` and run `sudo freshclam`
- **Rkhunter Fails**: Update database with `sudo rkhunter --update --rwo`
- **Permission Errors**: Check file permissions on scan directories
- **Timeout Issues**: Increase scan timeout or exclude large directories

#### **Configuration Issues**
- **Invalid Paths**: Edit `~/security-suite/configs/security-config.conf`
- **Missing Logs**: Check `~/security-suite/logs/` directory permissions
- **Service Not Running**: Enable with `systemctl --user enable security-daily-scan.timer`

#### **Performance Issues**
- **Slow Scans**: Exclude large directories or reduce scan scope
- **High Memory Usage**: Close other applications during scans
- **Disk Space**: Clean old logs with `find ~/security-suite/logs/ -name "*.log" -mtime +30 -delete`

#### **Common Solutions**
```bash
# Reset configuration to defaults
cp ~/security-suite/configs/security-config.conf.backup ~/security-suite/configs/security-config.conf

# Check all security tools status
~/security-suite/scripts/test-security-components.sh --all

# View recent scan results
ls -la ~/security-suite/logs/daily/ | head -10

# Clean up and reinstall
rm -rf ~/security-suite
./setup-security-suite.sh
```

**Need More Help?**
- 📋 **Installation Guide**: [docs/INSTALLATION.md](docs/INSTALLATION.md)
- 🔧 **User Guide**: [docs/USER_GUIDE.md](docs/USER_GUIDE.md)
- 🛡️ **Security Documentation**: [docs/SECURITY.md](docs/SECURITY.md)
- 🐛 **Report Issues**: [GitHub Issues](https://github.com/YahyaZekry/garuda-security-suite/issues)
---

## 🤝 **Contributing**

_"Join The Bear Code community - together we're stronger than yerba mate!"_

We welcome contributions! Whether you're:

- 🐛 **Reporting bugs**
- 💡 **Suggesting features**
- 🔧 **Improving code**
- 📖 **Enhancing documentation**

### **Development Setup**

```bash
git clone https://github.com/YahyaZekry/garuda-security-suite.git
cd garuda-security-suite
# Make your changes
# Test thoroughly
# Submit a pull request
```

### **Contributing Guidelines**

- 📋 Follow [CONTRIBUTING.md](CONTRIBUTING.md) for development standards
- 🤝 Respect [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community interaction
- 🧪 Run tests before submitting changes
- 📖 Update documentation for new features

---

## 📜 **License**

MIT License - Use it, modify it, share it!

_"Open source like sharing mate in a circle - better together!"_

---

## 🏷️ **About The Bear Code**

_"Crafting code with bear-like strength and mate-like energy!"_

**The Bear Code** is dedicated to creating powerful, reliable open-source tools that energize developers and secure systems. Like a good yerba mate session, our code brings people together and keeps systems running strong.

**Follow us:**

- 🐻 GitHub: [@YahyaZekry](https://github.com/YahyaZekry)
- 🧉 Philosophy: _"Strong code, energizing solutions, community-driven innovation"_

---

## 💬 **Slogans & Motto**

_"Security so strong, it's like yerba mate for your Linux soul!"_ ☕🐻

_"The Bear Code: Where security meets simplicity, energized by community!"_ 🛡️🧉

_"Brew your security like you brew your mate - with patience, precision, and passion!"_ ⏰🔒

---

## 🆘 **Support**

Need help? We're here like a reliable mate circle:

- 📋 **Issues**: [GitHub Issues](https://github.com/YahyaZekry/garuda-security-suite/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/YahyaZekry/garuda-security-suite/discussions)
- 📧 **Email**: Create an issue for direct support
- 📚 **Documentation**: [Complete Documentation Suite](docs/)

### **Troubleshooting**

- 📖 **Installation Help**: [Installation Guide](docs/INSTALLATION.md#troubleshooting)
- 🔧 **Configuration Issues**: [User Guide](docs/USER_GUIDE.md#troubleshooting)
- 🛡️ **Security Concerns**: [Security Documentation](docs/SECURITY.md#security-issues)
- 🔍 **API Questions**: [API Documentation](docs/API.md#integration-guidelines)

---

## 📈 **Roadmap**

_"Growing stronger like a well-seasoned mate gourd!"_

### ✅ **Phase 1 - Production Ready** (Current Release)
- [x] **100% Installation Success** - Multi-user compatibility verified
- [x] **Dynamic Path Resolution** - Works with any username
- [x] **Real Security Scanning** - ClamAV and Rkhunter fully functional
- [x] **Systemd Services** - All timers correctly generated and enabled
- [x] **Enterprise Error Handling** - Graceful degradation and recovery
- [x] **Input Validation** - Injection attack protection verified
- [x] **Documentation Accuracy** - All instructions tested and working
- [x] **Security Controls** - Comprehensive audit and logging

### 🔄 **Phase 2 - In Progress**
- [ ] Web dashboard for scan results
- [ ] Email notification system
- [ ] Advanced threat intelligence
- [ ] Integration with SIEM systems
- [ ] Mobile app notifications

### 📋 **Phase 3 - Planned**
- [ ] Machine learning threat detection
- [ ] Cloud backup of security logs
- [ ] Multi-distribution support
- [ ] Enterprise management console
- [ ] API for third-party integration

---

## 🏆 **Acknowledgments**

_"Gratitude shared like mate among friends!"_

- **Garuda Linux Team** - For the amazing distribution
- **Security Tool Developers** - ClamAV, rkhunter, chkrootkit, Lynis
- **Community Contributors** - For feedback, testing, and improvements
- **Open Source Community** - For the collaborative spirit

---

**🧉 "Secure your system, sip your mate, code like a bear!" 🐻**

---

_Made with 💙 by [The Bear Code](https://github.com/YahyaZekry) - Energizing security, one commit at a time!_
