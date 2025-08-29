# 🛡️ Garuda Security Suite

### _"Like yerba mate for your system - energizing protection that keeps you going!"_

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Garuda%20Linux-blue)](https://garudalinux.org/)
[![Security](https://img.shields.io/badge/Security-Enterprise%20Grade-green)](https://github.com/YahyaZekry/garuda-security-suite)

---

## 🧉 **The Bear Code Presents**

_"Sip your yerba mate while your system stays secure - automation that never sleeps!"_

A **complete interactive security automation suite** for Garuda Linux that provides enterprise-grade security scanning with the simplicity of your morning yerba mate ritual.

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/yahyazekry)

---

## ⚡ **Quick Start**

_"Ready faster than brewing yerba mate!"_

```bash
# Clone the repository
git clone https://github.com/YahyaZekry/garuda-security-suite.git
cd garuda-security-suite

# Make executable and run
chmod +x setup-security-suite.sh
./setup-security-suite.sh
```

**That's it!** 🎉 Your system will be protected with automated daily, weekly, and monthly security scans.

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

- **Daily scans** (default: 09:00) - Start your day secure
- **Weekly scans** (default: Monday 10:00) - Fresh week, fresh security
- **Monthly scans** (default: 1st day 11:00) - Monthly deep clean like changing mate leaves
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
│   ├── generated-YYYY-MM-DD/          # Timestamped scripts
│   ├── security-daily-scan.sh         # ← Symlinks for easy access
│   ├── security-weekly-scan.sh        # ← Always point to latest
│   ├── security-monthly-scan.sh       # ← No confusion about versions
│   ├── security-test.sh               # ← Quick testing
│   ├── common-functions.sh            # Shared utilities
│   └── notification-functions.sh      # Desktop notifications
├── logs/
│   ├── daily/                         # Daily scan results
│   ├── weekly/                        # Weekly scan results
│   ├── monthly/                       # Monthly scan results
│   └── manual/                        # Test & setup logs
├── configs/
│   └── security-config.conf           # Your custom configuration
└── backups/                           # Configuration backups
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

- **Daily**: Every day at 09:00 _(start your day secure)_
- **Weekly**: Every Monday at 10:00 _(fresh week, fresh security)_
- **Monthly**: 1st day of month at 11:00 _(monthly deep clean)_

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

---

## 📖 **Usage Examples**

### 🧪 **Quick Security Test**

```bash
cd ~/security-suite/scripts
./security-test.sh
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
```

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

---

## 📈 **Roadmap**

_"Growing stronger like a well-seasoned mate gourd!"_

- [ ] Support for additional Linux distributions
- [ ] Web dashboard for scan results
- [ ] Integration with security incident response
- [ ] Machine learning threat detection
- [ ] Cloud backup of security logs
- [ ] Mobile app notifications

---

**🧉 "Secure your system, sip your mate, code like a bear!" 🐻**

---

_Made with 💙 by [The Bear Code](https://github.com/YahyaZekry) - Energizing security, one commit at a time!_
