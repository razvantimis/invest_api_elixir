defmodule InvestData do
  @moduledoc """

  """
  alias InvestData.{StockPrice, CurrencyExchange}

  def fetch_stock_price(symbols) do
    StockPrice.DBSync.fetch_stock_price(symbols)
  end

  def fetch_exchange_rates() do
    CurrencyExchange.DBSync.fetch_currency_exchange_rates()
  end
end
