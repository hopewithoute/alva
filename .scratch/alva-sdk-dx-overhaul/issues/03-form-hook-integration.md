Status: done

## Parent

.scratch/alva-sdk-dx-overhaul/PRD.md

## What to build

Integrate `useAlvaForm` into the domain-nested SDK to provide a type-safe form hook per action.

Instead of passing magic strings (e.g., `useAlvaForm("sales.create_order")`), developers should call `alva.sales.use_create_order_form({ initialValues })`. Update the internal `useAlvaForm.ts` implementation to support this structure, and update the codegen to expose these wrappers on the domain object.

End-to-end slice: Migrate a form-heavy component (e.g., `MerchantInventoryItem.vue`) to use the new domain form hook.

## Acceptance criteria

- [ ] Domain objects expose `use_<action>_form` for actions.
- [ ] The generated form hook is fully type-safe regarding `initialValues` and the submit result.
- [ ] A form component is migrated and works end-to-end.

## Blocked by

- .scratch/alva-sdk-dx-overhaul/issues/02-domain-nested-sdk-core.md
