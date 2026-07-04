import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { getHooks } from "live_vue"
import components from "../vue"
import "../css/app.css"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...getHooks(components) },
})

liveSocket.connect()
window.liveSocket = liveSocket
