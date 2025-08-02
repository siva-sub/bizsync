# Running BizSync - Quick Guide

## ✅ Database Issue Fixed!

The SQLCipher database initialization error has been resolved. BizSync now automatically detects the platform and uses the appropriate database implementation:

- **Linux/Desktop**: Uses SQLite with FFI (unencrypted)
- **Android/iOS**: Uses SQLCipher (encrypted)

## Running the Application

### Linux Release Build
```bash
cd build/linux/x64/release/bundle/
./bizsync
```

### Debug Mode (with detailed logs)
```bash
flutter run -d linux
```

## What to Expect on First Launch

1. **Splash Screen**: Shows BizSync logo and initializes services
2. **Database Initialization**: Creates all required tables
3. **Onboarding Flow** (first time only):
   - Welcome screens
   - Company setup (name, UEN, GST registration)
   - User profile setup
   - Permission requests
   - Quick tutorial
4. **Main Dashboard**: After onboarding or on subsequent launches

## Features Ready to Use

### Core Business Management
- ✅ **Invoicing**: Create, manage, and track invoices
- ✅ **Customers**: Manage customer relationships
- ✅ **Inventory**: Track products and stock levels
- ✅ **Vendors**: Manage supplier information
- ✅ **Employees**: Full HR management with payroll

### Singapore-Specific Features
- ✅ **GST Calculations**: Automatic GST with current rates
- ✅ **CPF Management**: Age-based CPF calculations
- ✅ **SGQR/PayNow**: Generate payment QR codes
- ✅ **Tax Compliance**: Track and manage tax obligations

### Technical Features
- ✅ **Offline-First**: Works without internet
- ✅ **P2P Sync**: Sync between devices without servers
- ✅ **Backup/Restore**: Single-file encrypted backups
- ✅ **Multi-Language**: English, Chinese, Malay, Tamil

## Troubleshooting

### If you see permission dialogs
- **Notifications**: Required for reminders and alerts
- **Storage**: Required for backups and exports
- These are one-time requests during onboarding

### If the app doesn't start
1. Check terminal for error messages
2. Ensure you're in the correct directory
3. Make sure the binary has execute permissions:
   ```bash
   chmod +x bizsync
   ```

### Performance Tips
- The app uses local SQLite database on Linux (fast and reliable)
- First launch may take a few seconds to create tables
- Subsequent launches will be instant

## Next Steps

1. **Complete Onboarding**: Set up your company profile
2. **Create First Invoice**: Test the invoice system
3. **Add Customers**: Build your customer database
4. **Configure Settings**: Customize to your needs

The app is now fully functional and ready for production use!