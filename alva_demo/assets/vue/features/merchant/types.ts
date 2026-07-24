import type { Order } from "@/js/alva/types";
export const ORDER_STATUS = {
  NEW: "new",
  PROCESSING: "processing",
  FULFILLED: "fulfilled"
} as const;

export const ORDER_FILTER_ALL = "all";
export type MerchantConsoleTab = "orders" | "inventory" | "support";
export const MESSAGE_SENDER = {
  MERCHANT: "merchant",
  SHOPPER: "shopper"
} as const;

export type OrderAction = "begin_processing" | "fulfill";
export type OrderPendingAction = OrderAction | null;

export const ORDER_ACTION_PENDING_LABELS: Record<OrderAction, string> = {
  begin_processing: "Processing...",
  fulfill: "Fulfilling..."
};

export const ORDER_LIFECYCLE_ACTION_LABELS: Partial<Record<Order["lifecycle_status"], string>> = {
  new: "Begin Processing",
  processing: "Fulfill Order"
};

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
