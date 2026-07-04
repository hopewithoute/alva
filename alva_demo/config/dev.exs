import Config

config :alva_demo, AlvaDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "commerce_showcase_dev_secret_key_base_that_is_long_enough_for_signed_cookie_sessions_123",
  watchers: [
    npm: ["run", "dev", cd: Path.expand("../assets", __DIR__)]
  ]

config :alva_demo, dev_routes: true

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
