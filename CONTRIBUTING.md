# Contributing to BizSync

Thank you for your interest in contributing to BizSync! We welcome contributions from the community and are grateful for your help in making this project better.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Community](#community)

## 🤝 Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. By participating, you are expected to uphold this code.

### Our Standards

- Be respectful and inclusive
- Exercise empathy and kindness
- Focus on what is best for the community
- Accept constructive criticism gracefully
- Show courtesy and respect towards other community members

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: Version 3.16.0 or higher
- **Dart SDK**: Version 3.0.0 or higher
- **Git**: For version control
- **IDE**: VS Code, Android Studio, or IntelliJ IDEA with Flutter plugins

### Platform-Specific Requirements

#### For Android Development
- Android SDK (API 23+)
- Android Studio or VS Code with Android extensions
- Java Development Kit (JDK) 11+

#### For Linux Development
- Ubuntu 20.04+ or equivalent Linux distribution
- GTK 3.0+ development libraries
- CMake and other build tools

```bash
# Install required packages on Ubuntu
sudo apt-get install build-essential cmake ninja-build clang gtk+-3.0-dev
```

## 🛠️ Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/bizsync.git
cd bizsync
```

### 2. Install Dependencies

```bash
# Get Flutter packages
flutter pub get

# Generate code (if needed)
flutter packages pub run build_runner build
```

### 3. Verify Setup

```bash
# Check Flutter setup
flutter doctor

# Run the app
flutter run -d linux  # For Linux
flutter run -d android  # For Android (with device/emulator connected)
```

## 📝 Contributing Guidelines

### Types of Contributions

We welcome various types of contributions:

- 🐛 **Bug Fixes**: Fix issues and improve stability
- ✨ **New Features**: Add new functionality
- 📚 **Documentation**: Improve or add documentation
- 🎨 **UI/UX Improvements**: Enhance user interface and experience
- ⚡ **Performance Optimizations**: Improve app performance
- 🧪 **Tests**: Add or improve test coverage
- 🔒 **Security Enhancements**: Improve security features

### Before You Start

1. **Check existing issues**: Look for existing issues or discussions
2. **Create an issue**: If you're planning a major change, create an issue first
3. **Discuss**: Engage with maintainers and community for feedback
4. **Plan**: Break down large features into smaller, manageable pieces

## 🔄 Pull Request Process

### 1. Create a Branch

```bash
# Create and switch to a new branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### Branch Naming Convention

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions or modifications
- `security/` - Security-related changes

### 2. Make Your Changes

- Keep changes focused and atomic
- Write clear, concise commit messages
- Follow the coding standards outlined below
- Add tests for new functionality
- Update documentation as needed

### 3. Test Your Changes

```bash
# Run all tests
flutter test

# Run specific tests
flutter test test/path/to/specific_test.dart

# Check code formatting
dart format --set-exit-if-changed .

# Run static analysis
flutter analyze
```

### 4. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "feat: add invoice export to PDF functionality"
```

#### Commit Message Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or modifying tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(invoices): add PDF export functionality
fix(sync): resolve CRDT merge conflict issue
docs(readme): update installation instructions
test(customers): add unit tests for customer service
```

### 5. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create a pull request through GitHub interface
```

### Pull Request Guidelines

- **Title**: Use a clear, descriptive title
- **Description**: Provide a detailed description of changes
- **Link Issues**: Reference related issues using `Fixes #123` or `Closes #123`
- **Screenshots**: Include screenshots for UI changes
- **Testing**: Describe how you tested your changes
- **Breaking Changes**: Clearly document any breaking changes

## 🐛 Issue Reporting

### Before Creating an Issue

1. **Search existing issues**: Check if the issue already exists
2. **Use latest version**: Ensure you're using the latest version
3. **Minimal reproduction**: Create a minimal example that reproduces the issue

### Issue Templates

We provide templates for different types of issues:

- **Bug Report**: For reporting bugs
- **Feature Request**: For requesting new features
- **Question**: For asking questions
- **Security Issue**: For security-related concerns (use private disclosure)

### Bug Report Format

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior

**Expected behavior**
What you expected to happen

**Screenshots**
If applicable, add screenshots

**Environment:**
- Platform: [Android/Linux/Windows/macOS]
- Version: [App version]
- Flutter version: [Flutter version]
- Device: [Device model if mobile]

**Additional context**
Any other context about the problem
```

## 💻 Coding Standards

### Dart/Flutter Guidelines

We follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style) and [Flutter Best Practices](https://docs.flutter.dev/development/best-practices).

### Code Formatting

```bash
# Format all Dart files
dart format .

# Format specific file
dart format lib/main.dart
```

### Linting

We use `flutter_lints` for code analysis:

```bash
# Run analyzer
flutter analyze

# Fix auto-fixable issues
dart fix --apply
```

### Architecture Guidelines

- **Clean Architecture**: Follow the established clean architecture pattern
- **SOLID Principles**: Adhere to SOLID design principles
- **Feature-First Structure**: Organize code by features, not by technical layers
- **Dependency Injection**: Use Riverpod for dependency management
- **State Management**: Use Riverpod for state management

### File Organization

```
lib/
├── core/                 # Core functionality
│   ├── constants/       # App constants
│   ├── error/          # Error handling
│   ├── services/       # Core services
│   └── utils/          # Utility functions
├── features/           # Feature modules
│   ├── feature_name/
│   │   ├── models/     # Data models
│   │   ├── repositories/ # Data repositories
│   │   ├── screens/    # UI screens
│   │   ├── services/   # Feature services
│   │   └── widgets/    # Feature widgets
└── presentation/       # Shared UI components
    ├── screens/       # Global screens
    ├── widgets/       # Reusable widgets
    └── providers/     # Global providers
```

### Naming Conventions

- **Files**: snake_case (e.g., `customer_service.dart`)
- **Classes**: PascalCase (e.g., `CustomerService`)
- **Variables**: camelCase (e.g., `customerId`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `API_BASE_URL`)
- **Private members**: prefix with underscore (e.g., `_privateMethod`)

## 🧪 Testing Guidelines

### Testing Philosophy

- **Test-Driven Development**: Write tests before implementing features
- **Comprehensive Coverage**: Aim for high test coverage
- **Fast Tests**: Keep unit tests fast and isolated
- **Reliable Tests**: Tests should be deterministic and reliable

### Types of Tests

#### Unit Tests
```dart
// Example unit test
test('should calculate tax correctly', () {
  final taxService = TaxService();
  final result = taxService.calculateGST(100);
  expect(result, 7.0);
});
```

#### Widget Tests
```dart
// Example widget test
testWidgets('should display customer name', (WidgetTester tester) async {
  await tester.pumpWidget(CustomerCard(customer: testCustomer));
  expect(find.text('John Doe'), findsOneWidget);
});
```

#### Integration Tests
```dart
// Example integration test
testWidgets('should complete customer creation flow', (WidgetTester tester) async {
  // Test complete user flow
});
```

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/customers/customer_service_test.dart

# Run tests in watch mode
flutter test --watch
```

## 📚 Documentation

### Code Documentation

- **Public APIs**: Document all public classes and methods
- **Complex Logic**: Add comments for complex business logic
- **TODOs**: Use TODO comments for future improvements
- **Examples**: Provide usage examples for complex APIs

```dart
/// Calculates GST for Singapore businesses.
/// 
/// [amount] The base amount before GST
/// [rate] The GST rate (default is 0.07 for 7%)
/// 
/// Returns the GST amount to be added.
/// 
/// Example:
/// ```dart
/// final gst = calculateGST(100); // Returns 7.0
/// ```
double calculateGST(double amount, {double rate = 0.07}) {
  return amount * rate;
}
```

### README Updates

When adding new features, update:
- Feature list in README
- Installation instructions (if needed)
- Usage examples
- Screenshots (if UI changes)

## 🌟 Community

### Getting Help

- **GitHub Discussions**: For questions and general discussions
- **Issues**: For bug reports and feature requests
- **Email**: Contact the maintainer at hello@sivasub.com

### Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes for significant contributions
- README acknowledgments

## 📋 Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)

### Release Checklist

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Create release notes
4. Tag the release
5. Build and upload artifacts
6. Announce the release

## 🙏 Thank You

Thank you for contributing to BizSync! Your efforts help make this project better for everyone. We appreciate your time and expertise.

---

For questions about contributing, please reach out to:
- **Maintainer**: Sivasubramanian Ramanthan
- **Email**: hello@sivasub.com
- **GitHub**: [@siva-sub](https://github.com/siva-sub)