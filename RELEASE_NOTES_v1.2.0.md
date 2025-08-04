# BizSync v1.2.0 Release Notes

## Release Date: January 2025

## Overview
This release addresses critical bugs, UI/UX improvements, and adds significant new features to enhance the business management capabilities of BizSync.

## 🐛 Bug Fixes

### Critical Fixes
- **Fixed database initialization error** (v1.1.1): Resolved "PRAGMA journal_mode = WAL" failure on some Android devices
- **Fixed future date display**: Invoices and transactions now show realistic past dates instead of future dates like "8/8/2025"
- **Fixed UI text truncation**: 
  - "GST Ca..." → "GST Category"
  - "Standard R" → "Standard Rate"
  - "Discount" → "Discount %"
  - "Tax Rate (%)" → "Tax Rate %"

### Data Management
- **Feature flag system**: Added developer settings to control demo data visibility
- **Demo data improvements**: 
  - Demo data now uses realistic dates (past 6 months for invoices)
  - Can be completely disabled via developer settings
  - Prevents fake data from appearing in production

## ✨ New Features

### 1. Recurring Invoices
- Create recurring invoice templates with flexible scheduling
- Support for daily, weekly, monthly, yearly patterns
- Automatic invoice generation based on schedules
- Track generation history and manage templates

### 2. Email Integration
- Send invoices directly via email with SMTP configuration
- Professional email templates for different scenarios
- Support for attachments (PDF invoices)
- Email tracking and history

### 3. PDF Generation
- Generate professional PDF invoices
- Customizable templates with company branding
- Support for multiple languages and currencies
- Batch PDF generation for multiple invoices

### 4. Customer Statements
- Generate detailed customer statements
- Aging analysis (30/60/90 days)
- Payment history tracking
- Balance reconciliation
- Bulk statement generation

### 5. Enhanced Financial Reports
- Comprehensive financial reporting dashboard
- Cash flow analysis with trends
- Revenue forecasting
- Expense tracking by category
- Export reports to PDF, Excel, or CSV

### 6. Developer Settings
- Control feature flags and demo data
- Debug mode for development
- Beta features toggle
- Clear app data and cache options

## 🎨 UI/UX Improvements
- Fixed text truncation issues throughout the app
- Improved responsive layouts for better space utilization
- Enhanced date picker with proper constraints
- Better error messages and user feedback

## 🔧 Technical Improvements
- Improved database error handling with fallback mechanisms
- Better CRDT synchronization reliability
- Enhanced notification system
- Performance optimizations for large datasets

## 📱 Platform Support
- Android: Minimum SDK 23 (Android 6.0)
- Linux Desktop: Full support with native features
- Improved compatibility across different Android devices

## 🚀 Installation
Download the APK from the releases page and install on your Android device. For Linux desktop, use the provided AppImage or build from source.

## ⚠️ Known Issues
- Some "coming soon" features may have limited functionality
- Invoice creation in recurring invoices requires additional setup

## 🔮 Coming Next
- Complete invoice workflow automation
- Advanced analytics and insights
- Multi-user collaboration features
- Cloud backup integration