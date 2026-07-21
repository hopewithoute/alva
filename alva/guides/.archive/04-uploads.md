# LiveView Uploads

This guide covers managing file uploads, progress tracking, live previews, and file reference binding using LiveVue and Alva.

---

## 1. Overview & Conventions

File uploads combine Phoenix LiveView's `allow_upload/3` capability with Vue component props.

* **Backend Upload Key:** String matching the event name handling the upload (e.g. `"catalog.upload_media"`).
* **LiveVue Prop Binding:** Must pass `@uploads.<key>` into `<.vue>` component props.
* **Frontend Component:** Receives LiveView upload state (`progress`, `isUploading`, `ref`) as reactive props.

---

## 2. Ash Backend Definition

Define an Ash action accepting an `Ash.Type.File` argument and apply a change handler to store the reference:

```elixir
# lib/alva_demo/catalog/product.ex
defmodule AlvaDemo.Catalog.Product do
  use Ash.Resource,
    domain: AlvaDemo.Catalog,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  alva do
    event(:catalog_upload_media, name: "catalog.upload_media", action: :upload_media)
  end

  actions do
    update :upload_media do
      public?(true)
      accept([])
      require_atomic?(false)
      argument(:media, Ash.Type.File, allow_nil?: false)

      change({AlvaDemo.Catalog.Changes.StoreMedia, arg: :media, attribute: :media_reference})
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :media_reference, :string do
      allow_nil?(false)
      public?(true)
    end
  end
end
```

```elixir
# lib/alva_demo/catalog/changes/store_media.ex
defmodule AlvaDemo.Catalog.Changes.StoreMedia do
  use Ash.Resource.Change

  def change(changeset, opts, _context) do
    file_arg = opts[:arg]
    attr = opts[:attribute]

    case Ash.Changeset.fetch_argument(changeset, file_arg) do
      {:ok, %Plug.Upload{filename: filename, path: path}} ->
        dest_path = Path.join(["priv", "static", "images", filename])
        File.cp!(path, dest_path)
        Ash.Changeset.force_change_attribute(changeset, attr, filename)

      _ ->
        changeset
    end
  end
end
```

---

## 3. LiveView Integration

Declare the upload event name in the `uploads:` key inside `use Alva.LiveView`, and pass `@uploads.media` to the Vue component props:

```elixir
# lib/alva_demo_web/live/merchant_console_live.ex
defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    uploads: ["catalog.upload_media"]

  def render(assigns) do
    ~H"""
    <.vue
      id="merchant-console"
      v-component="MerchantConsolePage"
      v-socket={@socket}
      media={@uploads.media}
    />
    """
  end
end
```

---

## 4. Frontend TypeScript Library Usage

In your Vue component, emit file upload requests and render upload progress bars:

```vue
<script setup lang="ts">
import { ref } from "vue";
import type { Product } from "@/js/alva/types";

const props = defineProps<{
  product: Product;
  isUploading?: boolean;
  uploadProgress?: number;
  uploadError?: string | null;
}>();

const emit = defineEmits<{
  (e: "requestUpload"): void;
}>();
</script>

<template>
  <div class="product-media-panel">
    <img 
      v-if="product.media_reference" 
      :src="`/images/${product.media_reference}`" 
      alt="Product Media"
      class="h-16 w-16 object-cover" 
    />

    <button 
      type="button"
      @click="emit('requestUpload')" 
      :disabled="isUploading"
    >
      {{ isUploading ? "Uploading..." : "Upload Media" }}
    </button>

    <div v-if="isUploading" class="h-1 w-full bg-gray-200">
      <div 
        class="h-full bg-blue-600 transition-all duration-300" 
        :style="{ width: `${uploadProgress || 0}%` }"
      ></div>
    </div>
  </div>
</template>
```
