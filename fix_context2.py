with open("CONTEXT.md", "r") as f:
    text = f.read()

text = text.replace("non-collection occurrences", "non-stream occurrences")
text = text.replace("such as a Collection Source event", "such as a Stream source event")
text = text.replace("already-active Collections or Signals", "already-active Streams or Signals")
text = text.replace("updates a collection", "updates a stream")
text = text.replace("Collection Source Input", "Stream Input")
text = text.replace("shape as Collections:", "shape as Streams:")
text = text.replace("do not own collection synchronization", "do not own stream synchronization")
text = text.replace("in a **Collection** operation", "in a **Stream** operation")
text = text.replace("reusable **Collection**", "reusable **Stream**")
text = text.replace("such as `collections:`, `signals:`", "such as `subscriptions:`")
text = text.replace("in `collections:` or `signals:`", "in `subscriptions:`")
text = text.replace("across `collections:`, `signals:`, and", "across `subscriptions:` and")
text = text.replace("both a **Collection**", "both a **Stream**")
text = text.replace("primary collection/list update path", "primary stream/list update path")
text = text.replace("non-collection push path", "non-stream push path")

with open("CONTEXT.md", "w") as f:
    f.write(text)
