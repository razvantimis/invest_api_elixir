import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

if Config.config_env() == :dev do
  DotenvParser.load_file(".env")
end

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    """

database_username =
  System.get_env("DATABASE_USERNAME") ||
    raise """
    environment variable DATABASE_USERNAME is missing.
    """

database_password =
  System.get_env("DATABASE_PASSWORD") ||
    raise """
    environment variable DATABASE_USERNAME is missing.
    """

config :invest_data, InvestData.Repo,
  url: database_url,
  username: database_username,
  password: database_password,
  timeout: 60_000,
  idle_interval: 10_000,
  queue_target: 5_000,
  pool_size: 10,
  ssl_opts: [verify: :verify_none]

# The secret key base is used to sign/encrypt cookies and other secrets.
# A default value is used in config/dev.exs and config/test.exs but you
# want to use a different value for prod and you most likely don't want
# to check this value into version control, so we use an environment
# variable instead.
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

if Config.config_env() == :prod do
  config :invest_web, InvestWeb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base
end

config :invest_data, InvestData.Scheduler,
  jobs: [
    # Runs every midnight:
    {"@daily", {InvestData.StockDBSync, :polling_stock_price, []}},
    {"@daily", {InvestData.CurrencyExchange.DBSync, :polling_currency_exchange_rates, []}},
  ]

# ## Using releases
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :invest_web, InvestWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.

# ## Configuring the mailer
#
# In production you need to configure the mailer to use a different adapter.
# Also, you may need to configure the Swoosh API client of your choice if you
# are not using SMTP. Here is an example of the configuration:
#
#     config :invest, Invest.Mailer,
#       adapter: Swoosh.Adapters.Mailgun,
#       api_key: System.get_env("MAILGUN_API_KEY"),
#       domain: System.get_env("MAILGUN_DOMAIN")
#
# For this example you need include a HTTP client required by Swoosh API client.
# Swoosh supports Hackney and Finch out of the box:
#
#     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
#
# See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
