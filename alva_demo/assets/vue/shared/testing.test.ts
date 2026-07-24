import { describe, test, expect } from "vitest";
import { createMockAlvaClient } from "@/js/alva";

describe("Alva Testing Utility", () => {
  test("createMockAlvaClient creates type-safe query refs and mutation spies", async () => {
    const mockAlva = createMockAlvaClient({
      products: [{ id: "prod-1", name: "Broadsheet Mug", stock: 42 }],
      orders: [{ id: "ord-101", customer_name: "Ahmad", status: "pending" }]
    });

    // Verify query refs
    const { data: products } = mockAlva.catalog.use_list_products_query(() => ({}));
    expect(products.value).toHaveLength(1);
    expect(products.value[0].name).toBe("Broadsheet Mug");

    // Verify mutation spies
    const result = await mockAlva.sales.fulfill({ id: "ord-101" });
    expect(result.ok).toBe(true);
    expect(mockAlva.sales.fulfill).toHaveBeenCalledWith({ id: "ord-101" });
  });
});
