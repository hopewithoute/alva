# Use ETS for showcase state

The commerce showcase will keep sample state in ETS-backed Ash resources instead of PostgreSQL so the app can focus on exercising Alva's UI and realtime surfaces without database setup friction. Product media uploads are the exception: they exercise the Ash file upload path and `ash_storage` integration while resource records remain ephemeral. This is a deliberate demo constraint: ETS state is suitable for seeded showcase data, while durable commerce persistence is outside the sample's scope.
