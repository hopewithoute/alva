# LiveVue Persistent Layout Navigation Blank Page

This note captures the blank-page issue we hit in the Alva commerce showcase
when using LiveVue persistent layout Pattern 1.

## Symptom

Client-side navigation changes the URL, and the shared layout shell still
renders, but the page content area becomes empty. A full browser refresh then
renders the target page correctly.

In the showcase, the failure showed up when navigating between:

- `/`
- `/storefront`
- `/console`

## Expected Structure

The showcase uses LiveVue persistent layout Pattern 1:

- [root.html.heex](/var/www/ash_vue/alva_demo/lib/alva_demo_web/components/layouts/root.html.heex)
  renders the persistent shell with `<.vue id="layout" v-component="AppLayout" />`
- Route LiveViews inject their page component into that shell with
  `v-inject="layout"`
- [index.ts](/var/www/ash_vue/alva_demo/assets/vue/index.ts) is the local
  LiveVue adapter that mounts the root Vue app

## Root Cause

The page injector was present in the DOM after LiveView navigation, but the
root Vue app did not reliably pick up the newly registered slot content.

The problem was in the local LiveVue adapter:

```ts
render: () => h(component as Component, props, slots)
```

Passing `slots` directly meant the root render could miss newly added slot keys
after morphdom navigation. The layout component stayed mounted, the injector
element existed, but `AppLayout` still saw an empty `<slot />`.

This looked like a layout or morphdom problem from the outside, but the actual
break was slot reactivity at the Vue adapter boundary.

## Fix

Render with a shallow copy of the slot map so Vue re-reads the current slot
keys on each render:

```ts
render: () => h(component as Component, props, { ...slots })
```

That is the current implementation in
[index.ts](/var/www/ash_vue/alva_demo/assets/vue/index.ts).

## Why This Works

LiveVue registers the injected page component after navigation. Spreading the
slot object creates a fresh object for the root render, so Vue sees the updated
slot set and `AppLayout` receives the new page content without requiring a full
refresh.

## Troubleshooting Checklist

- Confirm the layout target id is stable: `id="layout"`
- Confirm the route page component uses `v-inject="layout"`
- If the URL changes but content is blank, inspect whether the injector element
  exists in the DOM while `#layout main` is empty
- Check the local LiveVue adapter before assuming the issue is in router or
  LiveView navigation

## References

- LiveVue persistent layout docs:
  `https://live-vue.hexdocs.pm/persistent_layout.html`
- LiveVue navigation example:
  `https://livevue.skalecki.dev/examples/navigation`
