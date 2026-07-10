# LiveView Uploads

Alva seamlessly integrates with Phoenix LiveView uploads. The `alva.use_upload()` hook provides a reactive interface to manage file selection, previews, progress tracking, and file cancellation.

## Implementing Uploads

To handle file uploads, you define the upload on the server in your LiveView, and bind to it on the frontend using its name.

### Example: Uploading Product Media

```vue
<script setup lang="ts">
import { useAlva } from "@/alva";

const alva = useAlva();

// The "media" string must match the name used in `allow_upload/3` in your Elixir LiveView.
const {
  entries,
  dropTarget,
  select,
  cancel,
  uploading,
  progress
} = alva.use_upload("media");

// Handle form submission
const form = alva.catalog.use_upload_media_form({
  initial: { product_id: "123" }
});
</script>

<template>
  <form @submit.prevent="form.submit">
    <!-- Dropzone Area -->
    <div ref="dropTarget" class="dropzone" @click="select">
      <p>Drag and drop files here, or click to browse.</p>
    </div>

    <!-- Preview and Progress -->
    <ul class="upload-list">
      <li v-for="entry in entries" :key="entry.ref">
        <!-- Live preview of the image -->
        <img v-if="entry.url" :src="entry.url" width="100" />
        
        <div class="details">
          <span>{{ entry.name }}</span>
          
          <!-- Progress bar -->
          <progress :value="entry.progress" max="100"></progress>
          
          <!-- Error handling -->
          <span v-if="entry.error" class="error">{{ entry.error }}</span>
        </div>

        <button type="button" @click="cancel(entry.ref)">Remove</button>
      </li>
    </ul>

    <button type="submit" :disabled="form.submitting || uploading">
      Upload Files
    </button>
  </form>
</template>

<style scoped>
.dropzone {
  border: 2px dashed #ccc;
  padding: 2rem;
  text-align: center;
  cursor: pointer;
}
.error { color: red; }
</style>
```

## Combining Uploads with Forms

In Phoenix LiveView, file uploads are naturally tied to form submissions. Notice in the example above how we check `:disabled="form.submitting || uploading"`. You should prevent form submission while files are still in the process of chunking to the server.
