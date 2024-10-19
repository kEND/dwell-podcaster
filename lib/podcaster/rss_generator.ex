defmodule Podcaster.RSSGenerator do
  @moduledoc """
  Generates RSS feeds for teaching series.
  """

  require EEx

  EEx.function_from_file(:defp, :render_rss, "lib/podcaster_web/templates/rss.xml.eex", [:assigns])

  def generate_feed(series) do
    assigns = %{
      series: series,
      most_recent_pub_date: series.most_recent_pub_date
    }

    render_rss(assigns)
  end

  defp format_date(nil), do: ""

  defp format_date(date) when is_binary(date) do
    date
  end

  defp format_date(%NaiveDateTime{} = date) do
    date
    |> DateTime.from_naive!("Etc/UTC")
    |> format_date()
  end

  defp format_date(%DateTime{} = date) do
    Calendar.strftime(date, "%a, %d %b %Y %H:%M:%S GMT")
  end

  defp format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)

    [hours, minutes, seconds]
    |> Enum.map(&String.pad_leading(Integer.to_string(&1), 2, "0"))
    |> Enum.join(":")
  end

  defp format_duration(_), do: "00:00:00"
end
