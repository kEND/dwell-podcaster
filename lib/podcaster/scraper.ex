defmodule Podcaster.Scraper do
  @http_client Application.compile_env(:podcaster, :http_client, HTTPoison)
  @dwell_url "https://dwellcc.org"

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
      :url
    ]
  end

  def execute(url) do
    series = scrape_series(url)
    teachings = Enum.map(series.teachings, &scrape_teaching/1)

    first_image_url =
      teachings
      |> Enum.find(& &1.image_url)
      |> case do
        nil -> nil
        teaching -> teaching.image_url
      end

    %{series | teachings: teachings, image_url: first_image_url}
  end

  def scrape_series(url, series \\ nil) do
    series = series || %Series{}

    with {:ok, body} <- @http_client.get(url),
         {:ok, document} <- Floki.parse_document(body.body) do
      series = Map.update(series, :teachings, extract_teaching_ids(document), &(&1 ++ extract_teaching_ids(document)))

      description = extract_series_description(document)

      # regex match to extract title, author out of description
      [_, title, author, _year] = Regex.run(~r/(.+) by (.+) \((.+)\)/, description)

      series =
        series
        |> update_if_empty(:description, description)
        |> update_if_empty(:title, title)
        |> update_if_empty(:author, author)
        |> update_if_empty(:link, url)

      {url, _page_param?} = remove_page_param(url)

      # Check for pagination and scrape additional pages if necessary
      next_page_url = find_next_page_url(document, url)
      if next_page_url, do: scrape_series(next_page_url, series), else: series
    else
      error -> raise "Failed to scrape series: #{inspect(error)}"
    end
  end

  def scrape_teaching(id) do
    url = "https://www.dwellcc.org/teaching/#{id}"

    with {:ok, body} <- @http_client.get(url),
         {:ok, document} <- Floki.parse_document(body.body) do
      script =
        document
        |> Floki.find("script[type='application/ld+json']")
        |> List.first()
        |> elem(2)
        |> List.first()

      {:ok, data} = Jason.decode(script)

      audio = get_audio(data)

      %Teaching{
        title: data["name"],
        description: data["abstract"],
        pub_date: audio.uploadDate,
        audio_url: audio.contentUrl,
        guid: "#{id}",
        author: audio.author.name,
        subtitle: data["about"],
        image_url: "#{@dwell_url}#{audio.author.image}",
        explicit: "no",
        episode_type: "full",
        block: false,
        url: audio.isPartOf
      }
    else
      error -> raise "Failed to scrape teaching: #{inspect(error)}"
    end
  end

  defp update_if_empty(map, key, value) do
    Map.update(map, key, value, fn existing ->
      if is_nil(existing) or existing == "", do: value, else: existing
    end)
  end

  defp extract_teaching_ids(document) do
    document
    |> Floki.find("#teachingList div")
    |> Floki.attribute("data-key")
  end

  defp extract_series_description(document) do
    "Series: " <> description =
      document
      |> Floki.find("#active-filters ul li")
      |> Floki.text()
      |> String.trim()

    description
  end

  defp remove_page_param(url) do
    uri = URI.parse(url)
    query_params = URI.decode_query(uri.query || "")
    updated_params = Map.delete(query_params, "page")

    updated_query =
      if Enum.empty?(updated_params) do
        nil
      else
        URI.encode_query(updated_params)
      end

    uri = %{uri | query: updated_query}
    {URI.to_string(uri), updated_query != uri.query}
  end

  defp find_next_page_url(document, url) do
    document
    |> Floki.find(".pagination .next")
    |> Floki.filter_out("li .next .disabled")
    |> Floki.find("a")
    |> Floki.attribute("data-page")
    |> List.first()
    |> case do
      nil -> nil
      page -> url <> "&page=#{page}"
    end
  end

  defp get_audio(data) do
    data["hasPart"]
    |> List.first()
    |> Enum.reduce(%{}, fn
      {k, v}, acc when is_list(v) ->
        first_v = List.first(v)

        if is_map(first_v) do
          Map.put(
            acc,
            String.to_atom(k),
            Enum.reduce(first_v, %{}, fn {k2, v2}, acc2 ->
              Map.put(acc2, String.to_atom(k2), v2)
            end)
          )
        else
          Map.put(acc, String.to_atom(k), first_v)
        end

      {k, v}, acc when is_map(v) ->
        Map.put(
          acc,
          String.to_atom(k),
          Enum.reduce(v, %{}, fn {k2, v2}, acc2 ->
            Map.put(acc2, String.to_atom(k2), v2)
          end)
        )

      {k, v}, acc ->
        Map.put(acc, String.to_atom(k), v)
    end)
  end
end
