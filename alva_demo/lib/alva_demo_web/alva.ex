defmodule AlvaDemoWeb.Alva do



  def dispatch(event, params, socket) do
    result = Alva.Dispatcher.dispatch(event, params, domains: [AlvaDemo.Academics])
    {:reply, result, socket}
  end
end
