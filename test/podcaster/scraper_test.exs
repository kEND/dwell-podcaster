defmodule Podcaster.ScraperTest do
  use ExUnit.Case, async: true
  import Mox

  # Set up the mock expectations before each test
  setup :verify_on_exit!

  @series_fixture "test/fixtures/series-list.html"
  @teaching_fixture "test/fixtures/heb-intro.html"

  describe "scrape_series/1" do
    test "extracts teaching IDs from a series page" do
      series_url = "https://www.dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26"
      html_content = File.read!(@series_fixture)

      expect(MockHTTPoison, :get, fn ^series_url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html_content}}
      end)

      teaching_ids = Podcaster.Scraper.scrape_series(series_url)

      assert is_list(teaching_ids)
      assert length(teaching_ids) > 0
      assert Enum.all?(teaching_ids, &is_binary/1)
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

      teaching = Podcaster.Scraper.scrape_teaching(teaching_id)

      assert teaching.title == "Introduction"

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
end
