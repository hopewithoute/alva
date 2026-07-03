defmodule Alva.Resource.Event do
  defstruct [
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

defmodule Alva.Resource.Stream do
  defstruct [:name, :operations, :__spark_metadata__]
end

defmodule Alva.Resource.Signal do
  defstruct [:name, :on, :expose_metadata, :__spark_metadata__]
end

defmodule Alva.Resource do
  @moduledoc """
  Spark DSL Extension for LiveVue configuration in Ash Resources.
  """

  @stream_operation_schema [
    on: [
      type: :string,
      required: true,
      doc: "The Ash PubSub published event name that triggers this stream operation."
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

  @stream %Spark.Dsl.Entity{
    name: :stream,
    describe: "A LiveVue stream projection mapped to Ash PubSub published events.",
    examples: [
      """
      stream :students do
        insert on: "student_created"
        update on: "student_updated"
        delete on: "student_deleted"
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

  @signal %Spark.Dsl.Entity{
    name: :signal,
    describe: "A semantic non-collection callback mapped to an Ash PubSub published event.",
    examples: [
      """
      signal "students.import_completed",
        on: "student_import_completed"
      """
    ],
    target: Alva.Resource.Signal,
    args: [:name],
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The domain-unique signal event name delivered to Vue."
      ],
      on: [
        type: :string,
        required: true,
        doc: "The Ash PubSub published event name that triggers this signal."
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
      event "students.list", action: :read
      """
    ],
    target: Alva.Resource.Event,
    args: [:name],
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The string event name that the Vue client will call."
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
    entities: [@event, @stream, @signal],
    schema: []
  }

  use Spark.Dsl.Extension,
    sections: [@live_vue],
    verifiers: [Alva.Resource.Verifiers.VerifyActions],
    transformers: []
end
