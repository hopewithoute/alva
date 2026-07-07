import type { Order } from "../../../js/alva/types";

export interface OrderFilters {
  status: Order["lifecycle_status"] | "all";
  customer: string;
  product: string;
}

export interface InventoryFilters {
  query: string;
  low_stock: boolean;
}

export interface ConversationFilters {
  customer: string;
  waiting: boolean;
}
