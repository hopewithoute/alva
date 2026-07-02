defmodule Alva.Resource.Event do
  defstruct [:name, :action, :lookup, :__spark_metadata__]
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
      ]
    ]
  }

  @live_vue %Spark.Dsl.Section{
    name: :live_vue,
    describe: "Configure how this resource is exposed to LiveVue",
    entities: [@event],
    schema: []
  }

  use Spark.Dsl.Extension,
    sections: [@live_vue],
    transformers: []
end
