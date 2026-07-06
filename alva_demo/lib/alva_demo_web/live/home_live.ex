defmodule AlvaDemoWeb.HomeLive do
  use AlvaDemoWeb, :live_view

  def render(assigns) do
    ~H"""
    <.vue id="home-page" v-component="HomePage" v-inject="layout" v-socket={@socket} />
    """
  end
end
