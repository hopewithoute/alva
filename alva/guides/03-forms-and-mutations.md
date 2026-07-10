# Forms and Mutations

When submitting data to the server, you often need to manage form state, track loading indicators, and display validation errors. The Alva SDK provides a `use_[action]_form` hook for every mutation action (create, update, destroy).

## Using Forms

The form composable returns reactive state and a `submit` function. It automatically captures and maps server-side Ash validation errors to the respective fields.

### Example: Creating a Product

```vue
<script setup lang="ts">
import { useAlva } from "@/alva";

const alva = useAlva();

const form = alva.catalog.use_create_product_form({
  // Initial form values
  initial: {
    name: "",
    price: 0,
    stock: 0
  },
  // Optional callbacks
  onSuccess: (product) => {
    console.log("Created successfully!", product);
    form.reset();
  },
  onError: (error) => {
    console.error("Failed to create product", error);
  }
});
</script>

<template>
  <form @submit.prevent="form.submit">
    <!-- Name Field -->
    <div>
      <label>Product Name</label>
      <input v-model="form.data.name" type="text" />
      <span v-if="form.errors.name" class="error">
        {{ form.errors.name.join(', ') }}
      </span>
    </div>

    <!-- Price Field -->
    <div>
      <label>Price</label>
      <input v-model.number="form.data.price" type="number" />
      <span v-if="form.errors.price" class="error">
        {{ form.errors.price.join(', ') }}
      </span>
    </div>

    <!-- Form Level Error -->
    <div v-if="form.error" class="global-error">
      {{ form.error.message }}
    </div>

    <button type="submit" :disabled="form.submitting">
      {{ form.submitting ? 'Creating...' : 'Create Product' }}
    </button>
  </form>
</template>
```

## Form Features

- `form.data`: Reactive object containing your form fields.
- `form.errors`: Reactive object mapping field names to an array of error strings.
- `form.submitting`: Boolean indicating if a request is in-flight.
- `form.submit()`: Function to execute the mutation.
- `form.reset()`: Resets `form.data` back to the `initial` state provided.
- `form.clearErrors()`: Clears the current validation errors.
