export const CATEGORIES = ['전시', '뮤지컬', '연극', '음악', '무용', '축제'] as const
export type Category = typeof CATEGORIES[number]
export interface User { id: number; email: string; name: string; categories: string[]; tags: string[]; survey_completed: boolean }
export interface Content {
  id: number; title: string; subtitle: string; category: string; region: string; venue: string; address: string;
  start_date: string; end_date: string; price: number; price_text: string; description: string; image_url: string;
  source: string; source_url: string; tags: string[]; is_sample: boolean; bookable: boolean;
  collected_at: string; bookmarked: boolean; rating: number | null; review_count: number; recommendation_reason: string | null;
}
export interface ContentPage { items: Content[]; total: number; page: number; size: number }
export interface Review { id: number; user_id: number; name: string; rating: number; body: string; updated_at: string }
export interface Order { payment_id: string; content_id: number; order_name: string; quantity: number; amount: number; cancelled_amount: number; currency: string; status: string; created_at: string }
export interface Reservation { id: number; payment_id: string; content_id: number; title: string; venue: string; start_date: string; status: string; quantity: number; amount: number }
export interface PaymentConfig { enabled: boolean; refunds_enabled: boolean; store_id: string; channel_key: string }
