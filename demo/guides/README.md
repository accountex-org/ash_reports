# AshReports Demo - User Guides

Welcome to the comprehensive documentation for the AshReports Demo Application! This directory contains detailed guides to help you make the most of the demo system.

## 📚 Available Guides

### [📖 User Guide](user_guide.md)
**The complete reference** - Everything you need to know about using the demo application, including:
- Detailed IEx console commands with examples
- Complete web interface walkthrough
- Data model explanations
- Report types and features
- Performance analysis and benchmarking
- Comprehensive troubleshooting section
- FAQ with common questions and answers

**Best for**: First-time users, comprehensive reference, troubleshooting

### [🌐 Web Interface Guide](web_interface_guide.md)
**Browser-focused documentation** - Specific guide for using the web interface:
- Step-by-step web interface tour
- Browser compatibility information
- Mobile and accessibility features
- Real-time updates and LiveView integration
- Web-specific troubleshooting
- Performance optimization tips

**Best for**: Users who prefer the web interface, UI-focused workflows

### [⚡ Quick Reference](quick_reference.md)
**Fast access cheat sheet** - Essential commands and workflows:
- Most common IEx commands
- Quick start procedures
- Data volume reference table
- Troubleshooting quick fixes
- Pro tips and best practices

**Best for**: Experienced users, quick lookups, development workflows

## 🚀 Getting Started

### For Complete Beginners
1. Start with the [User Guide](user_guide.md) - read the "Getting Started" section
2. Follow the guided demo: `AshReportsDemo.start_demo()`
3. Refer back to specific sections as needed

### For Web Interface Users
1. Read the [Web Interface Guide](web_interface_guide.md)
2. Start the server: `mix phx.server`
3. Visit: `http://localhost:4000`

### For Experienced Developers
1. Check the [Quick Reference](quick_reference.md) for essential commands
2. Jump to specific sections in the User Guide as needed
3. Use the troubleshooting sections for any issues

## 🎯 Common Use Cases

### Demo and Presentation
- **Quick Demo**: Use `mix demo` or `AshReportsDemo.start_demo()`
- **Web Presentation**: Start `mix phx.server` and use browser interface
- **Performance Demo**: Run `AshReportsDemo.benchmark_reports()`

### Development and Testing
- **Development**: Use `:small` data volumes and [Quick Reference](quick_reference.md)
- **Testing Features**: Follow workflows in [User Guide](user_guide.md)
- **Web Development**: Use [Web Interface Guide](web_interface_guide.md)

### Learning AshReports
- **Understanding Concepts**: Read data model section in [User Guide](user_guide.md)
- **Report Types**: Explore report features in [User Guide](user_guide.md)
- **Best Practices**: Check pro tips in all guides

## 🔧 Quick Commands Reference

### Essential Start Commands
```bash
cd demo
iex -S mix                  # Console interface
mix phx.server             # Web interface
mix demo                   # Interactive demo
```

### Most Used IEx Commands
```elixir
AshReportsDemo.start_demo()                        # Guided demo
AshReportsDemo.generate_sample_data(:medium)       # Generate data
AshReportsDemo.run_report(:customer_summary, %{})  # Run report
AshReportsDemo.data_summary()                      # Check data
AshReportsDemo.reset_data()                        # Clear data
```

## 📋 Guide Contents Overview

| Topic | User Guide | Web Guide | Quick Ref |
|-------|------------|-----------|-----------|
| Getting Started | ✅ Complete | ✅ Web-focused | ✅ Commands |
| IEx Commands | ✅ Comprehensive | ❌ Not covered | ✅ Essential |
| Web Interface | ✅ Basic coverage | ✅ Detailed | ✅ URLs only |
| Data Model | ✅ Detailed | ❌ Not covered | ✅ Volume table |
| Report Types | ✅ All features | ✅ UI aspects | ✅ List only |
| Performance | ✅ Comprehensive | ✅ Web-specific | ✅ Quick tips |
| Troubleshooting | ✅ Complete | ✅ Web-focused | ✅ Quick fixes |
| Examples | ✅ Many examples | ✅ UI workflows | ✅ Code snippets |

## 🎨 Guide Features

### Code Examples
All guides include:
- **Copy-paste ready** Elixir code
- **Commented explanations** for complex operations
- **Real-world scenarios** with practical examples
- **Error handling** patterns and solutions

### Visual Aids
- **Tables** for quick reference data
- **Step-by-step workflows** for complex procedures
- **Structured sections** for easy navigation
- **Cross-references** between related topics

### Practical Focus
- **Real use cases** rather than abstract examples
- **Problem-solving oriented** troubleshooting
- **Performance considerations** for all operations
- **Best practices** from actual usage patterns

## 🔄 Updating and Maintenance

These guides are maintained alongside the demo application. When features are added or changed:

1. **User Guide** gets comprehensive updates
2. **Web Interface Guide** covers UI changes
3. **Quick Reference** adds new essential commands
4. **Cross-references** are updated across all guides

## 💬 Getting Help

If these guides don't answer your questions:

1. **Check the logs** in your IEx console or Phoenix server
2. **Try the troubleshooting sections** in the relevant guide
3. **Reset your environment** with `AshReportsDemo.reset_data()`
4. **Restart the application** if problems persist

The guides are designed to be comprehensive, but if you find gaps or have suggestions for improvements, they help make the demo experience better for everyone.

---

Happy exploring with AshReports! 🎉