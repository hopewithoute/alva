defmodule Alva.Resource.Event do
  @moduledoc false
  defstruct [
    :key,
    :name,
    :action,
    :lookup,
    :expose_metadata,
    :enable_filter,
    :validate_only,
    :__spark_metadata__
  ]
end

defmodule Alva.Resource.Signal do
  @moduledoc false
  defstruct [
    :key,
    :name,
    :authorize_with,
    :on,
    :expose_metadata,
    :__spark_metadata__
  ]
end

defmodule Alva.Resource do
  @moduledoc """
  Spark DSL Extension for LiveVue configuration in Ash Resources.
  """

  @event %Spark.Dsl.Entity{
    name: :event,
    describe: "A LiveVue event mapped to an Ash action",
    examples: [
      """
      event :students_list,
        name: "students.list",
        action: :read
      """
    ],
    target: Alva.Resource.Event,
    args: [:key],
    schema: [
      key: [
        type: :atom,
        required: true,
        doc: "The atom declaration key used by collection sources and other resource projections."
      ],
      name: [
        type: :string,
        required: true,
        doc: "The application-wide client-facing event name that the Vue client will call."
      ],
      action: [
        type: :atom,
        required: true,
        doc: "The Ash action to call."
      ],
      lookup: [
        type: :atom,
        required: false,
        doc: "The field to use for lookups (e.g. :id)."
      ],
      expose_metadata: [
        type: {:list, :atom},
        required: false,
        default: [],
        doc: "List of __metadata__ keys to expose in the response meta object."
      ],
      enable_filter: [
        type: :boolean,
        required: false,
        default: false,
        doc: "If true, the TypeScript client will accept a strictly typed filter AST."
      ],
      validate_only: [
        type: :boolean,
        required: false,
        default: false,
        doc:
          "If true, this event strictly runs Ash.Changeset or Ash.ActionInput validation without persisting."
      ]
    ]
  }

  @signal %Spark.Dsl.Entity{
    name: :signal,
    describe: "A reactive one-off notification that Vue clients can subscribe to dynamically.",
    target: Alva.Resource.Signal,
    args: [:key],
    schema: [
      key: [
        type: :atom,
        required: true,
        doc: "The application-wide capability declaration key."
      ],
      name: [
        type: :string,
        required: true,
        doc: "The public name exposed to Vue clients."
      ],
      authorize_with: [
        type: :atom,
        required: true,
        doc: "The action to use with Ash.can? for authorization."
      ],
      on: [
        type: {:wrap_list, {:or, [:atom, :string]}},
        required: true,
        doc: "The Ash PubSub occurrence keys that trigger this signal."
      ],
      expose_metadata: [
        type: {:list, :atom},
        required: false,
        default: [],
        doc: "List of __metadata__ keys to expose in the signal payload meta object."
      ]
    ]
  }

  @live_vue %Spark.Dsl.Section{
    name: :live_vue,
    describe: "Configure how this resource is exposed to LiveVue",
    entities: [@event, @signal],
    schema: []
  }

  use Spark.Dsl.Extension,
    sections: [@live_vue],
    verifiers: [Alva.Resource.Verifiers.VerifyActions],
    transformers: []

  @doc false
  def validate_scope(scope) when scope in [%{}, []], do: {:ok, scope}

  def validate_scope(scope) when is_map(scope) do
    if Enum.all?(scope, fn {k, v} -> is_atom(k) and validate_scope_entry(v) end) do
      {:ok, scope}
    else
      {:error,
       "Scope must be a valid schema map, e.g. %{id: :uuid, params: %{type: :map, required?: true}}"}
    end
  end

  def validate_scope(_), do: {:error, "Scope must be a map"}

  defp validate_scope_entry(spec) when is_list(spec) do
    spec |> Enum.into(%{}) |> validate_scope_entry()
  end

  defp validate_scope_entry(spec) when is_map(spec) do
    Map.has_key?(spec, :type) or Map.has_key?(spec, "type")
  end

  defp validate_scope_entry(type) when is_atom(type), do: true
  defp validate_scope_entry(_), do: false
end
