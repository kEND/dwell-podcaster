defmodule Podcaster.Scraper do
  @http_client Application.compile_env(:podcaster, :http_client, HTTPoison)

  @base_url "https://www.dwellcc.org"
  @api_url "https://www.dwellcc.org/api/org.dwellcc/TeachingFinder"

  defmodule Series do
    defstruct [
      :title,
      :description,
      :link,
      :author,
      :image_url,
      teachings: []
    ]
  end

  defmodule Teaching do
    @enforce_keys [:title, :description, :pub_date, :audio_url]
    defstruct [
      :title,
      :description,
      :pub_date,
      :audio_url,
      :guid,
      :author,
      :subtitle,
      :image_url,
      :explicit,
      :episode_type,
      :block,
      :url,
      duration: "PT36M07S"
    ]
  end

  def scrape_series(series_guid) do
    params = [
      SearchSeriesGuid: series_guid,
      # Adjust as needed to get all teachings in one request
      ItemsPerPage: 100,
      PageNumber: 1
    ]

    url = @api_url <> "/TeachingSearch?" <> URI.encode_query(params)

    with {:ok, %{status_code: 200, body: body}} <- @http_client.get(url),
         {:ok, data} <- Jason.decode(body),
         {:ok, teachings} <- scrape_teachings(data["Teachings"]),
         series <- parse_series(data["Series"], teachings) do
      {:ok, series}
    else
      {:error, %{reason: reason}} ->
        {:error, "HTTP request failed: #{reason}"}

      error ->
        {:error, "Failed to fetch series data: #{inspect(error)}"}
    end
  end

  defp scrape_teachings(teachings_data) do
    teachings = Enum.map(teachings_data, &scrape_teaching/1)

    if Enum.any?(teachings, &match?({:error, _}, &1)) do
      {:error, "Failed to scrape one or more teachings"}
    else
      {:ok, teachings}
    end
  end

  def scrape_teaching(%{"CanonicalUrl" => canonical_url} = teaching_data) do
    url = @base_url <> String.replace(canonical_url, "~", "")

    case @http_client.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        with {:ok, document} <- Floki.parse_document(body),
             script when not is_nil(script) <-
               Floki.find(document, "script[type='application/ld+json']") |> List.first(),
             {:ok, json_data} <- Jason.decode(elem(script, 2) |> List.first()) do
          parse_teaching(teaching_data, json_data)
        else
          nil -> {:error, "JSON-LD script not found"}
          error -> {:error, "Failed to parse teaching data: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Failed to fetch teaching: #{inspect(reason)}"}
    end
  end

  defp parse_series([series_data | _], teachings) do
    %Series{
      title: series_data["SeriesName"],
      link: "#{@base_url}/teachings?series=#{series_data["SeriesGuid"]}",
      description: "Teachings from Dwell Community Church - #{series_data["SeriesName"]}",
      # Update if there's a series-specific image
      image_url: "#{@base_url}/sites/default/files/podcast_image.jpg",
      teachings: teachings
    }
  end

  defp parse_teaching(api_data, json_data) do
    audio = json_data["hasPart"] |> List.first()

    %Teaching{
      title: api_data["Title"],
      url: json_data["url"],
      guid: api_data["TeachingGuid"],
      pub_date: parse_date(json_data["datePublished"]),
      description: json_data["abstract"],
      author: get_from_first_item(json_data["author"], "name"),
      audio_url: audio["contentUrl"],
      subtitle: api_data["TitleAbbr"],
      explicit: "no",
      image_url: @base_url <> get_from_first_item(json_data["author"], "image"),
      episode_type: "full",
      block: false
    }
  end

  defp get_from_first_item(map_in_list, key) when is_list(map_in_list) do
    map_in_list
    |> List.first()
    |> Map.get(key)
  end

  defp get_from_first_item(map, key), do: Map.get(map, key)

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date_to_iso8601(date)

      _ ->
        with [month, day, year] <- String.split(date_string, "/"),
             {:ok, date} <- Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)) do
          date_to_iso8601(date)
        else
          _ -> nil
        end
    end
  end

  defp date_to_iso8601(date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    |> DateTime.to_iso8601()
  end
end
