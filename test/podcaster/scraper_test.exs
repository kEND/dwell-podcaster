defmodule Podcaster.ScraperTest do
  use ExUnit.Case, async: true
  alias Podcaster.Scraper
  alias Podcaster.Scraper.Series
  alias Podcaster.Scraper.Teaching
  import Mox

  # Set up the mock expectations before each test
  setup :verify_on_exit!

  @series_fixture "test/fixtures/series-list.html"
  @page_2_fixture "test/fixtures/series-list-page-2.html"
  @page_3_fixture "test/fixtures/series-list-page-3.html"
  @teaching_fixture "test/fixtures/heb-intro.html"

  describe "scrape_series/1" do
    test "extracts teaching IDs from a series page" do
      series_url = "https://www.dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26"
      page_2_url = "https://www.dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26&page=2"
      page_3_url = "https://www.dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26&page=3"
      html_content = File.read!(@series_fixture)
      page_2_html_content = File.read!(@page_2_fixture)
      page_3_html_content = File.read!(@page_3_fixture)

      expect(MockHTTPoison, :get, fn ^series_url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html_content}}
      end)

      expect(MockHTTPoison, :get, fn ^page_2_url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: page_2_html_content}}
      end)

      expect(MockHTTPoison, :get, fn ^page_3_url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: page_3_html_content}}
      end)

      %Series{teachings: teachings, description: description, title: title, author: author, link: link} =
        Scraper.scrape_series(series_url)

      assert teachings == [
               "4184",
               "4194",
               "4197",
               "4218",
               "4211",
               "4223",
               "4228",
               "4233",
               "4238",
               "4256",
               "4261",
               "4360",
               "4274",
               "4281",
               "4287",
               "4289",
               "4294",
               "4300",
               "4302",
               "4364",
               "4358",
               "4363",
               "4370"
             ]

      assert length(teachings) == 23
      assert description == "Hebrews by Dennis McCallum (2015)"
      assert title == "Hebrews"
      assert author == "Dennis McCallum"
      assert link == "https://www.dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26"
    end
  end

  describe "scrape_teaching/1" do
    test "extracts teaching data from a teaching page" do
      teaching_id = "4184"
      teaching_url = "https://www.dwellcc.org/teaching/#{teaching_id}"
      html_content = File.read!(@teaching_fixture)

      expect(MockHTTPoison, :get, fn ^teaching_url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html_content}}
      end)

      %Teaching{} = teaching = Scraper.scrape_teaching(teaching_id)

      assert teaching.description ==
               "The God of the Bible is unique in His desire to communicate and to have a personal relationship with humanity. The most profound way in which He has done this is by choosing to come personally to Earth in the person of Jesus Christ. The person of Christ ushered in a way of relating to God that is far superior to following rules and laws: that is grace."

      assert teaching.pub_date == "01/08/2015"
      assert teaching.audio_url == "https://www.dwellcc.org/media/10BCD360-20F1-E2F3-0F12-B5B3B44BD18F.m4a"
      assert teaching.guid == "4184"
      assert teaching.author == "Dennis McCallum"
      assert teaching.subtitle == "Bible teaching/sermon/presentation about Hebrews 1:1-2:3; Philippians 2:7-8."
      assert teaching.image_url == "https://dwellcc.org/GetImage.ashx?guid=ef9b2d1a-afca-451d-825c-81abad617162"
      assert teaching.url == "https://www.dwellcc.org/teaching/4184/bible/hebrews/1/dennis-mccallum/2015/introduction"
    end
  end

  describe "execute/1" do
    test "scrapes a series and its teachings" do
      series_url = "https://dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26&page=3"

      expect(MockHTTPoison, :get, fn ^series_url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: File.read!("test/fixtures/series-list-page-3.html")}}
      end)

      # Mocking responses for individual teachings
      ["4358", "4363", "4370"]
      |> Enum.map(fn id -> "https://www.dwellcc.org/teaching/#{id}" end)
      |> Enum.each(fn teaching_url ->
        expect(MockHTTPoison, :get, fn ^teaching_url ->
          {:ok, %HTTPoison.Response{status_code: 200, body: File.read!("test/fixtures/heb-intro.html")}}
        end)
      end)

      result = Scraper.execute(series_url)

      assert %Scraper.Series{} = result
      assert result.title == "Hebrews"
      assert result.author == "Dennis McCallum"
      assert result.description == "Hebrews by Dennis McCallum (2015)"
      assert result.link == "https://dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26&page=3"
      assert result.image_url == "https://dwellcc.org/GetImage.ashx?guid=ef9b2d1a-afca-451d-825c-81abad617162"
      assert length(result.teachings) == 3

      Enum.each(result.teachings, fn teaching ->
        assert %Scraper.Teaching{} = teaching
        assert teaching.title != nil
        assert teaching.audio_url != nil
      end)
    end

    test "raises an error when scraping fails" do
      series_url = "https://dwellcc.org/teaching/series/invalid"

      expect(MockHTTPoison, :get, fn ^series_url ->
        {:error, %HTTPoison.Error{reason: "not found"}}
      end)

      assert_raise RuntimeError, ~r/Failed to scrape series/, fn ->
        Scraper.execute(series_url)
      end
    end
  end
end
