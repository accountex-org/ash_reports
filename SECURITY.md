# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in AshReports, please report it by emailing the maintainers directly. Do not create a public GitHub issue.

**Please include:**
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

We will acknowledge receipt within 48 hours and provide a timeline for addressing the issue.

## Security Measures

### Atom Table Exhaustion Protection

**Issue**: Elixir atoms are not garbage collected. Creating atoms dynamically from user input can lead to atom table exhaustion (default limit: ~1M atoms), causing the VM to crash (DoS vulnerability).

**Mitigation**: As of version 0.x.x, AshReports implements comprehensive atom table exhaustion protection:

1. **Whitelist-Based Validation**: All user-controlled string-to-atom conversions now use `AshReports.Security.AtomValidator` with strict whitelists
2. **Safe Field Names**: Field names from user data remain as strings instead of being converted to atoms
3. **Validated Enums**: Chart types, export formats, providers, and other enums are validated against known-safe lists

### Safe Patterns

#### ✅ Good - Using Whitelist Validator

```elixir
# Chart type validation
case AtomValidator.to_chart_type(user_input) do
  {:ok, :bar} -> render_bar_chart()
  {:error, :invalid_chart_type} -> {:error, "Invalid chart type"}
end

# Field names kept as strings
field_name = user_input  # Keep as string
Map.get(record, field_name)
```

#### ❌ Bad - Direct Atom Creation

```elixir
# NEVER do this with user input:
chart_type = String.to_atom(user_input)  # ⚠️ DANGEROUS

# NEVER do this:
defp convert_field(field) when is_binary(field) do
  String.to_existing_atom(field)
rescue
  ArgumentError -> String.to_atom(field)  # ⚠️ Creates atoms!
end
```

### Allowed Atom Values

The following whitelists are enforced by `AshReports.Security.AtomValidator`:

- **Chart Types**: `:bar`, `:line`, `:pie`, `:area`, `:scatter`
- **Export Formats**: `:json`, `:csv`, `:png`, `:svg`, `:pdf`, `:html`
- **Chart Providers**: `:chartjs`, `:d3`, `:plotly`, `:contex`
- **Aggregation Functions**: `:sum`, `:count`, `:avg`, `:min`, `:max`, `:median`
- **Sort Directions**: `:asc`, `:desc`

### Process Dictionary

**Status**: ⚠️ In Progress (Stage 2.5 of code review implementation)

Several modules currently use the process dictionary for state management:
- `AshReports.Formatter` - Format spec registry
- `AshReports.Cldr` - Locale storage
- `AshReports.PdfRenderer.PdfGenerator` - Session data

**Planned fixes**: These will be replaced with proper state management (ETS, GenServer, or explicit parameter passing) in Stage 2.5.

## Security Testing

### Testing Atom Exhaustion Protection

```elixir
defmodule SecurityTest do
  use ExUnit.Case

  test "rejects malicious atom creation attempts" do
    # Attempt to exhaust atom table
    malicious_inputs = for i <- 1..10_000, do: "malicious_atom_#{i}"

    Enum.each(malicious_inputs, fn input ->
      assert {:error, :invalid_chart_type} =
        AtomValidator.to_chart_type(input)
    end)

    # Verify atom table not exhausted
    assert :erlang.system_info(:atom_count) < 100_000
  end
end
```

### Security Review Checklist

When adding new features or reviewing code, check for:

- [ ] No `String.to_atom/1` calls on user-controlled input
- [ ] All dynamic atom creation uses `AtomValidator`
- [ ] Field names from user data/schema kept as strings
- [ ] Enum values validated against whitelists
- [ ] No process dictionary for user-specific state
- [ ] No SQL injection vectors in custom queries
- [ ] Authentication/authorization properly enforced
- [ ] Rate limiting on API endpoints
- [ ] Input validation on all external data

## Safe Coding Practices

### 1. Field Name Handling

```elixir
# User-provided field names should remain strings
def filter_data(records, filters) do
  Enum.filter(records, fn record ->
    Enum.all?(filters, fn {field_name, value} ->
      # Keep as string, try both string and atom keys
      Map.get(record, field_name) == value ||
        (try do
          Map.get(record, String.to_existing_atom(field_name)) == value
        rescue
          ArgumentError -> false
        end)
    end)
  end)
end
```

### 2. Enum Validation

```elixir
# Always validate enum values from user input
def set_chart_type(chart, type_string) do
  case AtomValidator.to_chart_type(type_string) do
    {:ok, chart_type} ->
      %{chart | type: chart_type}
    {:error, :invalid_chart_type} ->
      {:error, "Invalid chart type: #{type_string}. " <>
               "Allowed: bar, line, pie, area, scatter"}
  end
end
```

### 3. State Management

```elixir
# Use explicit parameter passing
def render_report(report, context, opts \\ []) do
  locale = Keyword.get(opts, :locale, "en")
  # Pass locale explicitly, don't use Process.put
  do_render(report, context, locale)
end

# Or use GenServer/Agent for shared state
defmodule ConfigRegistry do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end
end
```

## Vulnerability History

### CVE-YYYY-XXXXX (Fixed in vX.X.X)

**Severity**: High
**Issue**: Atom table exhaustion via user-controlled chart type strings
**Impact**: Denial of Service (DoS) by exhausting atom table memory
**Fix**: Implemented `AtomValidator` with strict whitelisting
**Credit**: Internal code review (October 2025)

## References

- [Elixir Security Best Practices](https://github.com/nccgroup/elixir-security-best-practices)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Erlang Security](https://www.erlang.org/doc/apps/system/misc#security)

## Contact

For security concerns, please contact the maintainers directly rather than opening public issues.
