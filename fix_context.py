import re

with open("CONTEXT.md", "r") as f:
    text = f.read()

# Remove specific deprecated definitions
text = re.sub(r"- \*\*Collection\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Collection Source\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Collection Activation Options\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Route Collection\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Source Input\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Collection Refresh\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Route Change Reload\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Collection Block\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Signal Block\*\*:.*?\n", "", text, flags=re.MULTILINE)
text = re.sub(r"- \*\*Signal Activation\*\*:.*?\n", "", text, flags=re.MULTILINE)

# Replace Collections with Streams
text = text.replace("Collections, Streams, and Signals", "Streams and Signals")
text = text.replace("Collection delta", "Stream delta")
text = text.replace("active Collections and Signals", "active Streams and Signals")
text = text.replace("even on pages without route-change Collection refresh behavior", "")
text = text.replace("before any route-change Collection refresh runs", "")
text = text.replace("update multiple Collections and/or fire multiple Signals", "update multiple Streams and/or fire multiple Signals")
text = text.replace("non-collection cases", "non-stream cases")
text = text.replace("Collection Sources", "Stream sources")
text = text.replace("Collection operation", "Stream operation")
text = text.replace("reusable Collection or Signal mapping", "reusable Stream or Signal mapping")
text = text.replace("described as Collections", "described as Streams")
text = text.replace("updating a collection", "updating a stream")
text = text.replace("old collections: and signals:", "old collections: and signals:")
text = text.replace("Collections, Signals, Streams,", "Streams, Signals,")
text = text.replace("collections:, signals:,", "subscriptions:,")
text = text.replace("activate a given Collection or Signal", "activate a given Stream or Signal")
text = text.replace("Duplicate entries in collections: or signals:", "Duplicate entries in subscriptions:")
text = text.replace("collections:, signals:, and projection-keyed", "subscriptions: and projection-keyed")
text = text.replace("as both a Collection and a Signal", "as both a Stream and a Signal")
text = text.replace("back both a Collection and a Signal", "back both a Stream and a Signal")
text = text.replace("owned by a route Collection", "owned by a route Stream")
text = text.replace("out-of-band collection updates", "out-of-band stream updates")
text = text.replace("collections: and signals:", "collections: and signals:")

# Add Subscription Block
text = text.replace("- **Stream**:", "- **Subscription Block**: The resource-level DSL boundary that unifies the old Collection and Signal blocks. It declares what server-owned reactive streams or callbacks are allowed to reach Vue.\n- **Stream**:")

with open("CONTEXT.md", "w") as f:
    f.write(text)
