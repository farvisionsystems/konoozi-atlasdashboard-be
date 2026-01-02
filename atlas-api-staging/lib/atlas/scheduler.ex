defmodule Atlas.Scheduler do
  use Quantum, otp_app: :atlas
  import Ecto.Query

  def run_reports do
    # Get current date in MM-DD-YYYY format
    current_date = Date.utc_today() |> Calendar.strftime("%m-%d-%Y")

    # Use the existing Reports context function to get active reports
    Atlas.Reports.list_active_reports()
    |> Enum.each(fn report ->
      # Call the controller endpoint
      AtlasWeb.ReportController.run_report(
        %Plug.Conn{},
        %{
          "report_uid" => report.id,
          "date" => current_date
        }
      )
    end)
  end
end
