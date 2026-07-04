import Config

config :alva_demo, AlvaDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "commerce_showcase_test_secret_key_base_that_is_long_enough_for_signed_cookie_sessions_123",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
