defmodule Mix.Tasks.Alva.Check do
  @shortdoc "Audits Ash resources for unexposed public actions and checks TypeScript SDK drift"
  @moduledoc since: "0.1.0"
  @moduledoc """
  Audits Ash resources and TypeScript SDK files for Alva.

  Checks:
    1. Unexposed Public Actions: Reports public Ash actions that are not yet exposed via `alva do ... end`.
    2. SDK Drift Detection: Verifies if generated TypeScript SDK files in `:alva, :output_dir` are up to date.

  ## Usage

      mix alva.check
  """

  use Mix.Task

  alias Alva.Codegen.DtoGenerator
  alias Ash.Resource.Info

  @impl true
  def run(_args) do
    Mix.Task.run("compile")

    app = Mix.Project.config()[:app]
    output_dir = Application.get_env(:alva, :output_dir, "assets/js/alva")

    domains = Ash.Info.domains(app)

    if domains == [] do
      Mix.shell().info("No Ash domains found for :#{app}.")
    else
      check_unexposed_actions(domains)
      check_sdk_drift(app, output_dir)
    end
  end

  defp check_unexposed_actions(domains) do
    Mix.shell().info("=== Checking Ash Public Actions ===")

    unexposed =
      for domain <- domains,
          resource <- Ash.Domain.Info.resources(domain),
          action <- Info.actions(resource),
          action.public? do
        {domain, resource, action}
      end
      |> Enum.reject(fn {_domain, resource, action} ->
        event_actions =
          Spark.Dsl.Extension.get_entities(resource, [:alva])
          |> Enum.filter(&match?(%Alva.Resource.Event{}, &1))
          |> Enum.map(& &1.action)

        action.name in event_actions
      end)

    if unexposed == [] do
      Mix.shell().info("✔ All public Ash actions are exposed via Alva events.")
    else
      Mix.shell().info(
        "ℹ Found #{length(unexposed)} public Ash actions not exposed via Alva events:"
      )

      Enum.each(unexposed, fn {_domain, resource, action} ->
        res_name = resource |> Module.split() |> List.last()
        Mix.shell().info("  • #{res_name}.#{action.name} (type: #{action.type})")
      end)
    end
  end

  defp check_sdk_drift(app, output_dir) do
    Mix.shell().info("\n=== Checking TypeScript SDK Drift ===")

    if not File.dir?(output_dir) do
      Mix.shell().error(
        "❌ Output directory #{output_dir} does not exist. Run `mix alva.codegen`."
      )
    else
      events_map = Alva.Registry.event_map(app)
      _signal_map = Alva.Registry.registry(app).signal_map

      resources =
        events_map
        |> Map.values()
        |> Enum.map(fn {resource, _event} -> resource end)
        |> Enum.uniq()

      types_content = DtoGenerator.generate_types_ts(resources, events_map)
      target_types_file = Path.join(output_dir, "types.ts")

      if File.exists?(target_types_file) and File.read!(target_types_file) == types_content do
        Mix.shell().info("✔ TypeScript SDK types.ts is in sync.")
      else
        Mix.shell().error(
          "⚠ TypeScript SDK is out of sync with backend Ash definitions. Run `mix alva.codegen`."
        )
      end
    end
  end
end
