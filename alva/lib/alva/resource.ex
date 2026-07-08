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

defmodule Alva.Resource.SubscriptionSource do
  @moduledoc false
  defstruct [:event, :__spark_metadata__]
end

defmodule Alva.Resource.SubscriptionOperation do
  @moduledoc false
  defstruct [:on, :op, :at, :limit, :update_only, :__spark_metadata__]
end

defmodule Alva.Resource.Subscription do
  @moduledoc false
  defstruct [
    :key,
    :name,
    :kind,
    :source,
    :scope,
    :resolve,
    :authorize_with,
    :on,
    :operations,
    :expose_metadata,
    :__spark_metadata__
  ]
end

defmodule Alva.Resource do
  @moduledoc """
  Spark DSL Extension for LiveVue configuration in Ash Resources.
  """

  @subscription_operation_schema [
    on: [
      type: {:or, [:atom, :string]},
      required: true,
      doc: "The Ash PubSub occurrence key that triggers this collection operation."
    ],
    at: [
      type: :integer,
      required: false,
      doc: "Optional position passed to Phoenix.LiveView.stream_insert/4."
    ],
    limit: [
      type: :integer,
      required: false,
      doc: "Optional limit passed to Phoenix.LiveView.stream_insert/4."
    ],
    update_only: [
      type: :boolean,
      required: false,
      doc: "Optional update_only flag passed to Phoenix.LiveView.stream_insert/4."
    ]
  ]

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

  @subscription_source %Spark.Dsl.Entity{
    name: :source,
    describe: "The command event used to load or reset this stream.",
    target: Alva.Resource.SubscriptionSource,
    schema: [
      event: [
        type: {:or, [:atom, :string]},
        required: true,
        doc: "The Alva event declaration key that returns this stream's snapshot."
      ]
    ]
  }

  @subscription_insert %Spark.Dsl.Entity{
    name: :insert,
    describe: "Insert or update a record in this stream when a published event occurs.",
    target: Alva.Resource.SubscriptionOperation,
    schema:
      Keyword.put(@subscription_operation_schema, :op,
        type: {:one_of, [:insert]},
        default: :insert
      )
  }

  @subscription_update %Spark.Dsl.Entity{
    name: :update,
    describe: "Update a record in this stream when a published event occurs.",
    target: Alva.Resource.SubscriptionOperation,
    schema:
      Keyword.put(@subscription_operation_schema, :op,
        type: {:one_of, [:update]},
        default: :update
      )
  }

  @subscription_delete %Spark.Dsl.Entity{
    name: :delete,
    describe: "Delete a record from this stream when a published event occurs.",
    target: Alva.Resource.SubscriptionOperation,
    schema:
      Keyword.put(@subscription_operation_schema, :op,
        type: {:one_of, [:delete]},
        default: :delete
      )
  }

  @subscription %Spark.Dsl.Entity{
    name: :subscription,
    describe: "A typed realtime capability (stream or signal) that clients can activate.",
    target: Alva.Resource.Subscription,
    args: [:key],
    entities: [
      source: [@subscription_source],
      operations: [@subscription_insert, @subscription_update, @subscription_delete]
    ],
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
      kind: [
        type: {:one_of, [:stream, :signal]},
        required: true,
        doc:
          "Whether this capability acts as a reactive list (stream) or a one-off notification (signal)."
      ],
      scope: [
        type: {:custom, Alva.Resource, :validate_scope, []},
        required: false,
        default: %{},
        doc:
          "The public input schema accepted before resolver/default merging. Plain entries like %{conversation_id: :uuid} are optional and nullable by default; use maps or keywords such as %{conversation_id: %{type: :uuid, required?: true, allow_nil?: false}} to tighten the contract."
      ],
      resolve: [
        type: :atom,
        required: true,
        doc: "The local function to call to resolve scope and topics."
      ],
      authorize_with: [
        type: :atom,
        required: false,
        doc: "The action to use with Ash.can? for authorization."
      ],
      on: [
        type: {:or, [:atom, :string]},
        required: false,
        doc: "For kind: :signal, the Ash PubSub occurrence key that triggers this signal."
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
    entities: [@event, @subscription],
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
