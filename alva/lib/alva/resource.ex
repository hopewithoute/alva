defmodule Alva.Resource.Event do
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

defmodule Alva.Resource.StreamOperation do
  defstruct [:on, :op, :__spark_metadata__]
end

defmodule Alva.Resource.CollectionSource do
  defstruct [:event, :mode, :__spark_metadata__]
end

defmodule Alva.Resource.CollectionOperation do
  defstruct [:on, :op, :at, :limit, :update_only, :__spark_metadata__]
end

defmodule Alva.Resource.Stream do
  defstruct [:name, :operations, :__spark_metadata__]
end

defmodule Alva.Resource.Collection do
  defstruct [:name, :source, :operations, :__spark_metadata__]
end

defmodule Alva.Resource.Signal do
  defstruct [:key, :name, :on, :expose_metadata, :__spark_metadata__]
end

defmodule Alva.Resource do
  @moduledoc """
  Spark DSL Extension for LiveVue configuration in Ash Resources.
  """

  @stream_operation_schema [
    on: [
      type: {:or, [:atom, :string]},
      required: true,
      doc: "The Ash PubSub occurrence key that triggers this stream operation."
    ]
  ]

  @insert %Spark.Dsl.Entity{
    name: :insert,
    describe: "Insert or update a record in this stream when a published event occurs.",
    target: Alva.Resource.StreamOperation,
    schema:
      Keyword.put(@stream_operation_schema, :op, type: {:one_of, [:insert]}, default: :insert)
  }

  @update %Spark.Dsl.Entity{
    name: :update,
    describe: "Update a record in this stream when a published event occurs.",
    target: Alva.Resource.StreamOperation,
    schema:
      Keyword.put(@stream_operation_schema, :op, type: {:one_of, [:update]}, default: :update)
  }

  @delete %Spark.Dsl.Entity{
    name: :delete,
    describe: "Delete a record from this stream when a published event occurs.",
    target: Alva.Resource.StreamOperation,
    schema:
      Keyword.put(@stream_operation_schema, :op, type: {:one_of, [:delete]}, default: :delete)
  }

  @collection_operation_schema [
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

  @collection_insert %Spark.Dsl.Entity{
    name: :insert,
    describe: "Insert or update a record in this collection when a published event occurs.",
    target: Alva.Resource.CollectionOperation,
    schema:
      Keyword.put(@collection_operation_schema, :op,
        type: {:one_of, [:insert]},
        default: :insert
      )
  }

  @collection_update %Spark.Dsl.Entity{
    name: :update,
    describe: "Update a record in this collection when a published event occurs.",
    target: Alva.Resource.CollectionOperation,
    schema:
      Keyword.put(@collection_operation_schema, :op,
        type: {:one_of, [:update]},
        default: :update
      )
  }

  @collection_delete %Spark.Dsl.Entity{
    name: :delete,
    describe: "Delete a record from this collection when a published event occurs.",
    target: Alva.Resource.CollectionOperation,
    schema:
      Keyword.put(@collection_operation_schema, :op,
        type: {:one_of, [:delete]},
        default: :delete
      )
  }

  @collection_source %Spark.Dsl.Entity{
    name: :source,
    describe: "The command event used to load or reset this collection.",
    target: Alva.Resource.CollectionSource,
    schema: [
      event: [
        type: {:or, [:atom, :string]},
        required: true,
        doc: "The Alva event declaration key that returns this collection's records."
      ],
      mode: [
        type: {:one_of, [:reset]},
        required: false,
        default: :reset,
        doc: "How the source result is applied to the collection."
      ]
    ]
  }

  @stream %Spark.Dsl.Entity{
    name: :stream,
    describe: "A LiveVue stream projection mapped to Ash PubSub published events.",
    examples: [
      """
      stream :students do
        insert on: :create
        update on: :rename
        delete on: :destroy
      end
      """
    ],
    target: Alva.Resource.Stream,
    args: [:name],
    entities: [
      operations: [@insert, @update, @delete]
    ],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The domain-unique stream projection name."
      ]
    ]
  }

  @collection %Spark.Dsl.Entity{
    name: :collection,
    describe: "A server-owned reactive list mapped to Phoenix LiveView streams.",
    examples: [
      """
      collection :students do
        source event: :students_list, mode: :reset
        insert on: :create
        update on: :rename
        delete on: :destroy
      end
      """
    ],
    target: Alva.Resource.Collection,
    args: [:name],
    entities: [
      source: [@collection_source],
      operations: [@collection_insert, @collection_update, @collection_delete]
    ],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The domain-unique collection name."
      ]
    ]
  }

  @signal %Spark.Dsl.Entity{
    name: :signal,
    describe: "A semantic non-collection callback mapped to an Ash PubSub published event.",
    examples: [
      """
      signal :students_import_completed,
        name: "students.import_completed",
        on: :import_completed
      """
    ],
    target: Alva.Resource.Signal,
    args: [:key],
    schema: [
      key: [
        type: :atom,
        required: true,
        doc: "The domain-unique signal declaration key used by LiveView activation."
      ],
      name: [
        type: :string,
        required: true,
        doc: "The client-facing signal event name delivered to Vue."
      ],
      on: [
        type: {:or, [:atom, :string]},
        required: true,
        doc: "The Ash PubSub occurrence key that triggers this signal."
      ],
      expose_metadata: [
        type: {:list, :atom},
        required: false,
        default: [],
        doc: "List of __metadata__ keys to expose in the signal payload meta object."
      ]
    ]
  }

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
        doc: "The client-facing event name that the Vue client will call."
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

  @live_vue %Spark.Dsl.Section{
    name: :live_vue,
    describe: "Configure how this resource is exposed to LiveVue",
    entities: [@event, @collection, @stream, @signal],
    schema: []
  }

  use Spark.Dsl.Extension,
    sections: [@live_vue],
    verifiers: [Alva.Resource.Verifiers.VerifyActions],
    transformers: []
end
