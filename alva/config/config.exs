import Config

config :spark, :formatter,
  remove_parens?: true,
  "Ash.Resource": [
    section_order: [
      :resource,
      :postgres,
      :attributes,
      :relationships,
      :aggregates,
      :calculations,
      :identities,
      :actions
    ]
  ]
