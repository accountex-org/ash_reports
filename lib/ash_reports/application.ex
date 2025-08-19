defmodule AshReports.Application do
  @moduledoc """
  AshReports Application - Supervisor for PDF generation and other runtime services.

  This application module provides supervision for ChromicPDF processes and other
  runtime services needed by AshReports, particularly for PDF generation capabilities.

  ## Services Supervised

  - **ChromicPDF Supervisor**: Manages ChromicPDF browser processes for PDF generation
  - **PDF Session Manager**: Tracks active PDF generation sessions and cleanup
  - **Temporary File Cleanup**: Periodic cleanup of temporary PDF generation files

  ## Configuration

  The application can be configured through application environment:

      config :ash_reports,
        chromic_pdf: [
          chrome_args: ["--no-sandbox", "--disable-gpu"],
          session_pool_size: 2,
          timeout: 60_000
        ],
        pdf_temp_cleanup_interval: 3_600_000  # 1 hour

  ## Usage

  This application is automatically started when AshReports is used and PDF
  generation is requested. It can also be started manually:

      {:ok, pid} = AshReports.Application.start(:normal, [])

  """

  use Application

  alias AshReports.PdfRenderer.{PdfSessionManager, TempFileCleanup}

  @doc """
  Starts the AshReports application supervisor.

  Starts supervision tree with ChromicPDF, session management, and cleanup services.
  """
  def start(_type, _args) do
    children = build_supervision_tree()

    opts = [strategy: :one_for_one, name: AshReports.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Builds the supervision tree based on configuration and available dependencies.

  Only includes ChromicPDF supervision if the dependency is available and
  PDF generation is configured.
  """
  def build_supervision_tree do
    base_children = [
      # PDF Session Manager for tracking active PDF generation sessions
      {PdfSessionManager, []},

      # Periodic cleanup of temporary files
      {TempFileCleanup, cleanup_config()}
    ]

    if chromic_pdf_available?() do
      [chromic_pdf_supervisor() | base_children]
    else
      base_children
    end
  end

  @doc """
  Checks if ChromicPDF is available and properly configured.
  """
  def chromic_pdf_available? do
    case Code.ensure_loaded(ChromicPDF) do
      {:module, ChromicPDF} ->
        # Check if ChromicPDF can start properly
        case Application.ensure_all_started(:chromic_pdf) do
          {:ok, _} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  @doc """
  Gets ChromicPDF configuration for supervision.
  """
  def chromic_pdf_config do
    Application.get_env(:ash_reports, :chromic_pdf, default_chromic_config())
  end

  # Private functions

  defp chromic_pdf_supervisor do
    chromic_config = chromic_pdf_config()

    %{
      id: ChromicPDF,
      start: {ChromicPDF, :start_link, [chromic_config]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 10_000
    }
  end

  defp cleanup_config do
    %{
      interval: Application.get_env(:ash_reports, :pdf_temp_cleanup_interval, 3_600_000),
      temp_dir_patterns: [
        "ash_reports_*.html",
        "ash_reports_*.pdf",
        "ash_reports_template_*.html"
      ],
      # 2 hours
      max_age_seconds: 7200
    }
  end

  defp default_chromic_config do
    [
      chrome_args: ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"],
      session_pool_size: 2,
      timeout: 60_000,
      ignore_certificate_errors: false,
      user_data_dir: Path.join(System.tmp_dir(), "ash_reports_chrome_data")
    ]
  end
end
