# AshReports Demo - Web Interface Guide

This guide focuses specifically on using the web interface to explore AshReports functionality through your browser.

## Getting Started with the Web Interface

### Starting the Web Server

```bash
cd demo
mix phx.server
```

The server will start on `http://localhost:4000` by default.

### Alternative Port Configuration

If port 4000 is in use:
```bash
PORT=4001 mix phx.server
```

## Web Interface Tour

### Homepage (`/`)

The main landing page provides:

- **System Overview**: Current status of the demo application
- **Quick Access Links**: Direct navigation to key features
- **Getting Started Tips**: Guidance for new users
- **System Health**: Indicators showing data availability and service status

### Reports Dashboard (`/reports`)

The main reports interface includes:

#### Navigation Header
- **AshReports Demo** branding and title
- **Available Reports** subtitle with description
- **Data Management Controls** (see below)

#### Data Management Panel
- **"Regenerate Sample Data" Button**:
  - Creates fresh demo data with `:small` volume
  - Shows success notification when complete
  - Automatically refreshes available reports
  - Takes 2-5 seconds to complete

#### Report Cards Grid
Each report displays as a card containing:
- **Report Title**: Descriptive name (e.g., "Simple Report")
- **Description**: Brief explanation of report contents and purpose
- **"View Report" Button**: Opens the specific report page
- **Status Indicator**: Shows if data is available for the report

Current available reports:
1. **Simple Report** (`/reports/simple`)
   - Basic tabular report showing customer data
   - Simple formatting and clean layout
   - Real-time data display

2. **Complex Report** (`/reports/complex`)
   - Advanced report with grouping and calculations
   - Multiple data sources integration
   - Enhanced formatting options

3. **Interactive Report** (`/reports/interactive`)
   - Real-time interactive features
   - Live filtering and updates
   - Dynamic parameter adjustment

### Individual Report Pages

#### Simple Report Page (`/reports/simple`)

**Layout Structure**:
- **Page Header**: Report title and description
- **Data Table**: Clean, responsive table with customer information
- **Action Buttons**: Data generation and refresh controls

**Table Features**:
- **Responsive Design**: Adapts to different screen sizes
- **Column Headers**: Clear field names and descriptions
- **Data Rows**: Customer information with proper formatting
- **Empty State**: Helpful message when no data is available

**Data Display**:
- Customer names and contact information
- Company affiliations
- Email addresses with mailto links
- Phone numbers with proper formatting
- Addresses with full details

**Interactive Elements**:
- **"Generate Sample Data" Link**: Creates demo data if none exists
- **Automatic Refresh**: Updates when new data is generated
- **Loading States**: Visual feedback during data operations

## User Interactions

### Data Generation Workflow

1. **Check Current State**: Page shows "No customers found" if data is empty
2. **Generate Data**: Click "Regenerate Sample Data" or "Generate sample data" link
3. **Wait for Completion**: Operation takes 2-5 seconds
4. **View Results**: Page automatically updates with new data
5. **Success Confirmation**: Flash message confirms successful generation

### Navigation Patterns

**From Homepage**:
- Click "Reports" in navigation or main content
- Direct links to specific report types

**Between Reports**:
- Use browser back button
- Navigate via main "Reports" section
- Bookmark specific report URLs for quick access

**Data Refresh**:
- Click "Regenerate Sample Data" from any reports page
- Data persists across different report views
- Reset data by regenerating (current data is replaced)

## Browser Compatibility

### Supported Browsers
- **Chrome/Chromium**: Full feature support
- **Firefox**: Full feature support
- **Safari**: Full feature support
- **Edge**: Full feature support

### Mobile Experience
- **Responsive Design**: Adapts to phone and tablet screens
- **Touch-Friendly**: Buttons and links sized appropriately
- **Readable Text**: Font sizes scale with device
- **Navigation**: Mobile-optimized menu structures

### Accessibility Features
- **Semantic HTML**: Proper heading structure and landmarks
- **Keyboard Navigation**: All interactive elements accessible via keyboard
- **Screen Reader Support**: Appropriate ARIA labels and descriptions
- **High Contrast**: Good color contrast ratios for readability

## Advanced Features

### Real-Time Updates

The web interface supports real-time updates in several ways:

**LiveView Integration**:
- Page content updates without full page refresh
- Real-time data synchronization
- Efficient partial page updates
- Maintains scroll position during updates

**Data Synchronization**:
- Changes in one browser tab reflect in others
- Multiple users can view the same data simultaneously
- Data generation by one user visible to others immediately

### Performance Optimization

**Efficient Loading**:
- Minimal initial page load time
- Progressive data loading for large datasets
- Optimized asset delivery
- Compressed CSS and JavaScript

**Memory Management**:
- Efficient data structures for large reports
- Garbage collection of unused components
- Minimal memory footprint in browser

### Developer Tools Integration

**Browser Developer Tools**:
- **Console**: View any JavaScript errors or warnings
- **Network Tab**: Monitor data loading and API calls
- **Elements Tab**: Inspect LiveView component structure
- **Performance Tab**: Analyze page performance characteristics

**Debugging Features**:
- Clear error messages for user-facing issues
- Graceful degradation when services unavailable
- Helpful guidance for common problems

## Customization Options

### URL Parameters

Some reports support URL parameters for direct access:

```
/reports/simple?volume=medium
/reports/complex?format=html
/reports/interactive?auto_refresh=true
```

### Browser Settings

**Recommended Settings**:
- Enable JavaScript (required for LiveView)
- Allow cookies (for session management)
- Enable local storage (for user preferences)

**Performance Settings**:
- Disable ad blockers that might block WebSocket connections
- Enable hardware acceleration for better rendering
- Clear browser cache if experiencing issues

## Troubleshooting Web Interface Issues

### Common Problems

#### Page Won't Load
**Symptoms**: Blank page, connection errors, timeout messages
**Solutions**:
1. Verify Phoenix server is running (`mix phx.server`)
2. Check correct URL: `http://localhost:4000`
3. Try different port if 4000 is occupied
4. Disable browser extensions that might interfere
5. Clear browser cache and cookies

#### Reports Show "No Data"
**Symptoms**: Empty tables, "No customers found" messages
**Solutions**:
1. Click "Regenerate Sample Data" button
2. Wait for data generation to complete (2-5 seconds)
3. Refresh page if data doesn't appear
4. Check browser console for JavaScript errors

#### Slow Performance
**Symptoms**: Slow page loads, delayed updates, unresponsive interface
**Solutions**:
1. Use smaller data volumes (`:small` instead of `:large`)
2. Close other browser tabs using significant resources
3. Clear browser cache and restart browser
4. Check system memory usage
5. Restart Phoenix server if performance degrades

#### LiveView Connection Issues
**Symptoms**: Page becomes static, no real-time updates, connection error messages
**Solutions**:
1. Check browser JavaScript console for WebSocket errors
2. Verify firewall/proxy settings allow WebSocket connections
3. Refresh the page to re-establish connection
4. Check network connectivity
5. Restart Phoenix server

### Browser-Specific Issues

#### Chrome/Chromium
- May block WebSocket connections in some security configurations
- Clear site data if experiencing persistent issues
- Check developer tools console for detailed error messages

#### Firefox
- May require enabling WebSocket in about:config for some versions
- Private browsing mode might limit some functionality
- Check Network tab in developer tools for connection issues

#### Safari
- WebSocket connections may be limited in some security settings
- Clear website data if experiencing issues
- Disable content blockers that might interfere

## Best Practices

### Optimal Usage Patterns

1. **Start Simple**: Begin with the Simple Report to understand basic functionality
2. **Generate Data First**: Always ensure sample data exists before exploring reports
3. **Use Appropriate Volumes**: Start with small datasets for responsiveness
4. **Bookmark Reports**: Save direct links to frequently used reports
5. **Monitor Performance**: Watch for slow responses and optimize accordingly

### Development Workflow

If you're developing or customizing the web interface:

1. **Use LiveReload**: Phoenix includes automatic browser refresh during development
2. **Monitor Logs**: Watch the Phoenix server output for errors and warnings
3. **Test Multiple Browsers**: Ensure compatibility across different browsers
4. **Check Mobile**: Test responsive design on different screen sizes
5. **Validate HTML**: Use browser developer tools to check for markup issues

### Security Considerations

**Data Privacy**:
- Demo uses fake data generated by Faker library
- No real customer or business data is used
- Safe for demonstration and testing purposes

**Network Security**:
- Default configuration binds to localhost only
- External access requires explicit configuration
- No authentication required for demo purposes

---

This web interface guide provides comprehensive coverage of using AshReports Demo through the browser. The interface is designed to be intuitive and user-friendly while showcasing the full power of the AshReports library.