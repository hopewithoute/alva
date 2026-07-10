defmodule Alva.Resource.Event do
  @moduledoc """
  Represents a single `event` definition within an `Alva.Resource` block.

  This struct is the target of the Spark DSL for the `event` entity. It holds the parsed
  configuration mapping an Ash action to a LiveVue event, including advanced options like 
  `expose_metadata`, `lookup`, and `validate_only`.
  """
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
  @moduledoc """
  Represents a single `signal` definition within an `Alva.Resource` block.

  This struct is the target of the Spark DSL for the `signal` entity. It holds the parsed
  configuration linking a frontend PubSub subscription request to an underlying Ash PubSub
  occurrence, including authorization requirements via `authorize_with`.
  """
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

  To expose your Ash framework resources to the frontend via the Alva SDK, you configure 
  your resources using the `Alva.Resource` extension. This maps Ash actions and PubSub 
  notifications to frontend-facing events and signals.

  ## Basic Configuration

  In your Ash Resource file, add `Alva.Resource` to your `extensions` list, and define 
  your exposed events in the `alva do ... end` block.

  ```elixir
  defmodule MyApp.Catalog.Product do
    use Ash.Resource,
      domain: MyApp.Catalog,
      data_layer: Ash.DataLayer.Ets,
      notifiers: [Ash.Notifier.PubSub], # Required for signals
      extensions: [Alva.Resource]

    pub_sub do
      module MyAppWeb.Endpoint
      prefix "product"
      
      # 1. Publish occurrences when actions run
      publish :update, ["updated"]
    end

    alva do
      # 2. Map Ash Actions to SDK Events
      event(:catalog_list_products, 
        # `name`: A custom string that becomes the function name in Vue (alva.catalog.list_products)
        name: "catalog.list_products", 
        # `action`: Must match the name of an action defined in the `actions do` block below
        action: :list
      )
      
      event(:catalog_create_product, 
        name: "catalog.create_product", 
        action: :create
      )
      
      # 3. Map PubSub Occurrences to SDK Signals
      signal(:product_updated_signal, 
        # `name`: The topic name the Vue client uses in alva.catalog.on_product_updated()
        name: "catalog.product_updated", 
        # `authorize_with`: Must match an action in `actions do` to run Ash.can? against
        authorize_with: :list, 
        # `on`: The occurrence key broadcasted by `publish :update, ["updated"]` in the pub_sub block
        on: ["updated"]
      )
    end

    actions do
      defaults [:read, :destroy]

      read :list do
        public?(true) # Required for all mapped events
      end
    end
  end
  ```

  ## Advanced Event Configuration

  The `event` DSL supports several advanced configurations to control how the SDK interacts with the action:

  - **`lookup` (atom):** The field to use for lookups (e.g. `:id`) when dispatching instance-level actions.
  - **`expose_metadata` (list of atoms):** Extracts keys from the `__metadata__` map of the Ash result and exposes them to the frontend SDK's response object.
  - **`enable_filter` (boolean):** If set to `true`, the generated TypeScript client will accept a strictly typed filter AST for `:read` actions, allowing the frontend to pass complex queries.
  - **`validate_only` (boolean):** If `true`, the event will strictly run `Ash.Changeset` or `Ash.ActionInput` validation without actually persisting or executing the action. Useful for live form validations.

  ## Signals (PubSub Subscriptions)

  The `signal` DSL exposes a reactive PubSub topic that Vue clients can subscribe to dynamically via `alva.domain.on_signal(...)`.

  - **`name` (string):** The public name exposed to Vue clients (e.g., `"catalog.product_updated"`).
  - **`authorize_with` (atom):** The Ash action to use with `Ash.can?` to authorize the subscription request. Alva ensures only permitted users can listen to the signal.
  - **`on` (list):** The Ash PubSub occurrence keys (from your `pub_sub` block) that trigger this signal.
  - **`expose_metadata` (list of atoms):** Like events, this exposes metadata in the signal payload.

  ## Security Considerations

  1. **Only Public Actions**: Alva enforces that any action mapped via an `event` must have `public?(true)`.
  2. **Actor Assignment**: Alva automatically injects the `current_user` (actor) and `current_tenant` (tenant) from your LiveView socket assigns into both *events* and *signal subscriptions*, preserving your existing Ash policies and permissions.
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

  @alva %Spark.Dsl.Section{
    name: :alva,
    describe: "Configure how this resource is exposed to LiveVue",
    entities: [@event, @signal],
    schema: []
  }

  use Spark.Dsl.Extension,
    sections: [@alva],
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
