import { api, getToken } from './client'

export const EVENT_TYPES = ['page_view', 'search', 'filter_use', 'content_view', 'recommendation_click', 'recommendation_impression', 'bookmark_add', 'bookmark_remove', 'review_submit', 'review_delete', 'survey_submit', 'reservation_checkout_started', 'payment_verified', 'payment_cancelled'] as const
export type EventType = typeof EVENT_TYPES[number]
export interface ActivityEvent {
  event_id: string; type: EventType; occurred_at: string; session_id: string; anonymous_id: string
  page: { path: string; referrer: string }; props: Record<string, unknown>; schema_version: 4
}

const QUEUE_KEY = 'culturepick.events.queue'
const SESSION_KEY = 'culturepick.events.session'
const ANON_KEY = 'culturepick.events.browser'
const MAX_BATCH = 10
const INTERVAL_MS = 3000
const id = () => crypto.randomUUID()
const stableId = (key: string) => {
  let value = sessionStorage.getItem(key)
  if (!value) { value = id(); sessionStorage.setItem(key, value) }
  return value
}
const readQueue = (): ActivityEvent[] => {
  try { const value = JSON.parse(localStorage.getItem(QUEUE_KEY) || '[]'); return Array.isArray(value) ? value.slice(-MAX_BATCH) : [] }
  catch { return [] }
}
let queue = readQueue()
let flushing = false
const persist = () => localStorage.setItem(QUEUE_KEY, JSON.stringify(queue))

export async function flushEvents() {
  if (!getToken() || flushing || !queue.length) return
  flushing = true
  const batch = queue.slice(0, MAX_BATCH)
  try {
    await api('/history/events/batch', { method: 'POST', body: JSON.stringify({ events: batch }) })
    const sent = new Set(batch.map(event => event.event_id))
    queue = queue.filter(event => !sent.has(event.event_id)); persist()
    if (queue.length >= MAX_BATCH) void flushEvents()
  } catch { /* Keep events for the next periodic retry. */ }
  finally { flushing = false }
}

export function track(type: EventType, props: Record<string, unknown> = {}) {
  if (!getToken()) return
  queue.push({ event_id: id(), type, occurred_at: new Date().toISOString(), session_id: stableId(SESSION_KEY),
    anonymous_id: stableId(ANON_KEY), page: { path: location.pathname + location.search, referrer: document.referrer }, props, schema_version: 4 })
  if (queue.length > MAX_BATCH) queue = queue.slice(-MAX_BATCH)
  persist()
  if (queue.length >= MAX_BATCH) void flushEvents()
}

export function startEventQueue() {
  const flush = () => { void flushEvents() }
  const onStorage = (event: StorageEvent) => { if (event.key === QUEUE_KEY) queue = readQueue() }
  window.addEventListener('online', flush); window.addEventListener('pagehide', flush); window.addEventListener('storage', onStorage)
  const timer = window.setInterval(flush, INTERVAL_MS)
  flush()
  return () => { window.clearInterval(timer); window.removeEventListener('online', flush); window.removeEventListener('pagehide', flush); window.removeEventListener('storage', onStorage) }
}
