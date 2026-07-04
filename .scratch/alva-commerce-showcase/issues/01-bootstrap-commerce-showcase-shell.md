Status: done

# Bootstrap Commerce Showcase Shell

## What to build

Create the initial Alva Commerce Showcase shell so a user can open a root entry page, navigate to the Customer Storefront, and navigate to the Merchant Console. The shell should prove the Phoenix, LiveView, LiveVue, Vite, and shadcn-vue integration path without adding commerce behavior yet.

## Acceptance criteria

- [x] The root route provides a small entry surface linking to the Customer Storefront and Merchant Console.
- [x] The Customer Storefront route and Merchant Console route render through LiveView host pages using LiveVue page components.
- [x] LiveVue is installed/configured at version `1.2` and the app uses the Vite-style component discovery expected by LiveVue.
- [x] Phoenix templates that host LiveViews use `<Layouts.app flash={@flash}>`.
- [x] Route-level smoke tests prove the root, Customer Storefront, and Merchant Console routes render.
- [x] The implementation does not reintroduce old Student, Academics, Communication, primitive demo routes, or PostgreSQL migrations.

## Blocked by

None - can start immediately
