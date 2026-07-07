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
    schema: Keyword.put(@collection_operation_schema, :op, type: {:one_of, [:insert]}, default: :insert)
  }

  @subscription_update %Spark.Dsl.Entity{
    name: :update,
    describe: "Update a record in this stream when a published event occurs.",
    target: Alva.Resource.SubscriptionOperation,
    schema: Keyword.put(@collection_operation_schema, :op, type: {:one_of, [:update]}, default: :update)
  }

  @subscription_delete %Spark.Dsl.Entity{
    name: :delete,
    describe: "Delete a record from this stream when a published event occurs.",
    target: Alva.Resource.SubscriptionOperation,
    schema: Keyword.put(@collection_operation_schema, :op, type: {:one_of, [:delete]}, default: :delete)
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
        doc: "Whether this capability acts as a reactive list (stream) or a one-off notification (signal)."
      ],
      scope: [
        type: :any,
        required: false,
        default: %{},
        doc: "The expected input parameter types for scope resolution (e.g. %{conversation_id: :uuid})."
      ],
      resolve: [
        type: :atom,
        required: true,
        doc: "The local function to call to resolve scope and topics."
      ],
      on: [
        type: {:or, [:atom, :string]},
        required: false,
        doc: "For kind: :signal, the Ash PubSub occurrence key that triggers this signal."
      ]
    ]
  }
