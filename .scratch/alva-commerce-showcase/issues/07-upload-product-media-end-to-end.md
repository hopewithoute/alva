Status: completed

# Upload Product Media End To End

## What to build

Allow merchant staff to upload Product Media for a Product through the Alva upload path. The upload should update the Product media reference and make the uploaded media visible in the Customer Storefront catalog, with progress and error states exposed in the Merchant Console.

## Acceptance criteria

- [ ] Product Media upload is modeled as a Product action unless implementation proves a separate resource is necessary.
- [ ] The Merchant Console provides Product Media upload controls with visible progress and error states.
- [ ] Upload submission uses the Alva/LiveVue upload integration and exercises the `ash_storage` path.
- [ ] Successful upload updates the Product media reference.
- [ ] The Customer Storefront catalog displays the updated Product Media.
- [ ] Tests cover the upload action argument handling, Alva upload path, Product media reference update, and storefront visibility.

## Blocked by

- 02-seed-product-catalog-through-alva
