ExUnit.start()

# Configure Mox for test doubles
Mox.defmock(AshReports.MockDataLayer, for: Ash.DataLayer)