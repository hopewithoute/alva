defmodule Alva do
  @moduledoc since: "0.1.0"
  @moduledoc """
  Alva provides a fully typed, auto-generated TypeScript SDK for Vue 3 that seamlessly 
  bridges your Vue frontend with your Elixir/Ash backend via `Phoenix.LiveView`.

  ## Overview

  Alva eliminates the need for manual API routing, REST endpoints, or GraphQL resolvers. 
  By directly connecting Ash Resources to LiveVue, Alva allows you to execute actions, 
  read streams, process uploads, and listen to PubSub signals directly from the frontend, 
  all with end-to-end TypeScript safety.

  ### Core Components

  - `Alva.Resource`: An Ash DSL extension to expose specific backend actions and signals to the frontend.
  - `Alva.LiveView`: A macro to inject auto-syncing data streams and upload handlers into Phoenix LiveViews.
  - `mix alva.codegen`: The mix task that reads your backend configuration and outputs a strict TypeScript API.

  For detailed walkthroughs, see the module documentation for `Alva.Resource` and `Alva.LiveView`, or the [Getting Started guide](guides/01-getting-started.md).
  """
end
