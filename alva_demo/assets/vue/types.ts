export interface Order {
  id: string;
  customer_name: string;
  quantity: number;
  product_id: string;
  lifecycle_status: string;
}

export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  stock: number;
  media_reference: string;
}
