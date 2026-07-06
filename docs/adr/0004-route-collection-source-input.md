# Route Collection Source Input

Route-owned Collections need a clear boundary between URL state and Ash action input.

Alva will use **Route Params** for URL and path params delivered by Phoenix route lifecycle callbacks, and **Source Input** for the payload sent to a Collection Source. Public APIs and docs should avoid using bare `params` for this boundary because it conflates Phoenix route params, Collection source input, and command/event input.

Resource `live_vue` collection definitions remain capability declarations: they say a Collection exists, name its Collection Source, and declare optional realtime Event-trigger mappings. They do not know URL shape.

Route activation through `use Alva.LiveView` owns Collection activation details, including Source Input and route-change reload behavior. A future route-change reload API should look like:

```elixir
use Alva.LiveView,
  domains: [MyApp.Sales],
  collections: [
    sales_orders: [
      source_input: :sales_order_source_input,
      reload_on: :route_change
    ]
  ],
  route_subscriptions: [
    {:sales_orders, :sales_order_topics}
  ]
```

The app owns URL semantics and may derive Source Input from Route Params:

```elixir
def sales_order_source_input(socket) do
  route = Alva.LiveView.route_params(socket)

  %{
    "status" => route["orders_status"],
    "customer_query" => route["orders_customer_query"]
  }
end
```

Alva owns the Collection Refresh mechanics: storing current Source Input, comparing old and new input, re-running the Collection Source when route changes require it, and keeping Vue props synchronized through LiveView streams and LiveVue diffs.

This keeps the mental model to two layers:

- Resource defines reusable Collection capability.
- Route activates that Collection, including Source Input and reload behavior.

We are intentionally not making Alva own URL naming conventions yet. A mapping DSL such as `source_input_from_route` may be added later for simple routes, but callback-based Source Input should be the first route-change reload API because it preserves app control and avoids premature URL-shape magic.
