defmodule AshReportsDemoWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered around all other layouts.
  The "app" layout is the default layout used by most pages.
  """
  use AshReportsDemoWeb, :html

  embed_templates "layouts/*"
end