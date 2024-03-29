defmodule InvestData.StockPrice.DBSync do
  @moduledoc """
    Sync between DB and price from web scraper
  """
  require Logger
  alias InvestData.{Repo, StockScraper, StockUtils, Entities.StockPrice, Utils.DateHelper}

  def fetch_stock_price(stock_list) do
    stock_price_db = get_stock_price_from_db(stock_list)

    missing_stocks =
      stock_list
      |> Enum.filter(fn stock ->
        not Enum.any?(stock_price_db, fn stock_db ->
          stock_db.symbol == StockUtils.create_symbol(stock)
        end)
      end)

    documents =
      stock_price_db
      |> Enum.map(&StockPrice.dump(&1))

    case Enum.count(missing_stocks) do
      0 ->
        {:ok, documents}

      _ ->
        prepared_missing_stock_price_list =
          missing_stocks
          |> Enum.flat_map(&fetch_stock_price_from_web(&1))
          |> Enum.map(&StockPrice.dump(&1))

        if Enum.count(prepared_missing_stock_price_list) > 0 do
          Repo.insert_all(StockPrice, prepared_missing_stock_price_list, ordered: false)
        end

        result =
          documents
          |> Enum.concat(
            prepared_missing_stock_price_list
            |> Enum.map(&Map.delete(&1, :_id))
          )

        {:ok, result}
    end
  end

  def polling_stock_price() do
    all_symbols =
      get_all_stocks()
      |> Enum.map(&StockUtils.parse_symbol(&1.symbol))

    stock_list =
      all_symbols
      |> Enum.flat_map(&fetch_stock_price_from_web(&1))
      |> Enum.map(&StockPrice.dump(&1))

    if Enum.count(stock_list) > 0 do
      Repo.insert_all(StockPrice, stock_list, ordered: false)
    end
  end

  defp get_all_stocks() do
    Repo.aggregate(StockPrice, [
      %{
        "$group" => %{
          _id: "$symbol",
          price: %{
            "$first": "$price"
          },
          date: %{
            "$first": "$date"
          }
        }
      },
      %{
        "$project": %{
          _id: false,
          symbol: "$_id",
          price: true,
          date: true
        }
      }
    ])
  end

  defp get_stock_price_from_db(stock_list) do
    symbols = stock_list |> Enum.map(&StockUtils.create_symbol(&1))

    %{:end_date => end_date, :start_date => start_date} =
      DateHelper.get_last_day_of_week() |> DateHelper.get_start_and_end_of_day()

    Repo.aggregate(StockPrice, [
      %{
        "$match" => %{
          symbol: %{
            "$in": symbols
          },
          date: %{
            "$gte": start_date,
            "$lt": end_date
          }
        }
      },
      %{"$sort" => [{"date", -1}]},
      %{
        "$group" => %{
          _id: "$symbol",
          price: %{
            "$first": "$price"
          },
          date: %{
            "$first": "$date"
          }
        }
      },
      %{
        "$project": %{
          _id: false,
          symbol: "$_id",
          price: true,
          date: true
        }
      }
    ])
  end

  defp fetch_stock_price_from_web(stock) do
    Logger.debug(
      "[Start] StockScraper.fetch_stock_price_from_web(#{stock.country}:#{stock.symbol})"
    )

    case StockScraper.fetch_stock_price(stock.country, stock.symbol) do
      {:ok, result} ->
        result
        |> Enum.map(
          &StockPrice.new(
            stock,
            DateTime.new!(&1.date, Time.new!(0, 0, 0, 0)),
            &1.price
          )
        )

      {:error, result} ->
        Logger.error(
          "[Error] StockScraper.fetch_stock_price_from_web(#{stock.country}:#{stock.symbol})"
        )

        result
    end
  end
end
