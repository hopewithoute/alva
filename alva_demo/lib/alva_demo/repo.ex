defmodule AlvaDemo.Repo do
  use Ecto.Repo,
    otp_app: :alva_demo,
    adapter: Ecto.Adapters.Postgres
end
