defmodule Podcaster.Scraper do
  @http_client Application.compile_env(:podcaster, :http_client, HTTPoison)
  @dwell_url "https://dwellcc.org"

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

  def scrape_series(url) do
    with {:ok, body} <- @http_client.get(url),
         {:ok, document} <- Floki.parse_document(body.body) do
      teaching_ids =
        document
        |> Floki.find("#teachingList a")
        |> Floki.attribute("href")
        |> Enum.map(fn href ->
          href
          |> String.split("/")
          |> List.last()
        end)

      # Check for pagination and scrape additional pages if necessary
      next_page = Floki.find(document, ".pagination .next a") |> Floki.attribute("href")
      teaching_ids ++ if next_page != [], do: scrape_series(next_page), else: []
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
