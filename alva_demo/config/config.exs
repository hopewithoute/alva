import Config

config :alva_demo, ash_domains: [AlvaDemo.Catalog, AlvaDemo.Sales]
config :alva_demo,
  generators: [timestamp_type: :utc_datetime]

config :alva_demo, AlvaDemoWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: AlvaDemoWeb.ErrorHTML, json: AlvaDemoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AlvaDemo.PubSub,
  live_view: [signing_salt: "commerce-shell"]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
