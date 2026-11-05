import { ArrowRight, ArrowUpRight, Frame, Drama, Music2, AudioLines, Flower2, PartyPopper, Sparkles, MoveUpRight } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { useState } from 'react'
import type { FormEvent } from 'react'
import { CATEGORIES } from '../types'
import type { ContentPage } from '../types'
import { useApi } from '../hooks'
import { useSession } from '../context'
import { track } from '../api/events'
import { ContentCard } from '../components/ContentCard'
import { EmptyState, ErrorState, Loading } from '../components/States'

export const categoryIcons = [Frame, Drama, AudioLines, Music2, Flower2, PartyPopper]
export function Home() {
  const navigate = useNavigate()
  const s = useSession()
  const [category, setCategory] = useState('')
  const listing = useApi<ContentPage>(`/contents?size=8&sort=popular${category ? `&category=${encodeURIComponent(category)}` : ''}`)
  const recs = useApi<ContentPage>('/recommendations?size=4')
  const search = (e: FormEvent<HTMLFormElement>) => { e.preventDefault(); const q = new FormData(e.currentTarget).get('q'); track('search', { query: String(q || '') }); navigate(`/explore?q=${encodeURIComponent(String(q || ''))}`) }
  return <>
    <section className="hero-section container"><div className="hero">
      <div className="hero-copy"><div className="hero-kicker"><span />일상에 새로운 감각을</div><h1>마음이 끌리는<br />순간을 발견하세요.</h1><p>전시부터 공연까지, 당신의 다음 문화생활.<br />좋아하는 것을 만나고, 나의 취향을 넓혀보세요.</p><Link to="/explore" className="button dark">오늘의 문화 탐색<ArrowUpRight size={18} /></Link><span className="hero-caption">작은 발견 하나가, 특별한 하루로.</span></div>
      <div className="hero-art"><img src="/posters/hero.svg" alt="곡선과 빛이 만나는 추상 조형 작품" /><div className="art-label"><span className="art-pill">이번 주의 발견 · 샘플 큐레이션</span><h2>감각의 조각들</h2><p>익숙한 일상을 새롭게 바라보는 시간</p><Link to="/explore?category=전시" className="art-arrow" aria-label="전시 콘텐츠 둘러보기"><MoveUpRight size={25} /></Link></div></div>
    </div></section>
    <section className="container discovery-bar"><p>오늘은 어떤 문화가<br /><strong>끌리나요?</strong></p><div className="category-shortcuts">{CATEGORIES.map((c, i) => { const Icon = categoryIcons[i]; return <Link key={c} to={`/explore?category=${encodeURIComponent(c)}`}><span className={`category-icon color-${i}`}><Icon size={25} strokeWidth={1.6} /></span>{c}</Link> })}</div><form onSubmit={search} className="home-search"><input aria-label="문화 콘텐츠 검색" name="q" maxLength={100} placeholder="전시, 공연, 공간을 검색해 보세요" /><button type="submit" aria-label="검색"><ArrowRight size={21} /></button></form></section>
    <section className="container section"><div className="section-heading"><div><h2>지금, 눈여겨볼 문화</h2><p>새로운 경험이 기다리는 곳을 모았어요.</p></div><Link to="/explore" className="text-link">전체 보기<ArrowRight size={17} /></Link></div>
      <div className="content-tabs" aria-label="콘텐츠 분야">{['', ...CATEGORIES].map(c => <button key={c} className={category === c ? 'active' : ''} onClick={() => setCategory(c)} aria-pressed={category === c}>{c || '전체'}</button>)}</div>
      {listing.loading ? <Loading /> : listing.error ? <ErrorState error={listing.error} retry={listing.retry} /> : listing.data?.items.length ? <><div className="card-grid">{listing.data.items.map(c => <ContentCard key={`${c.id}-${c.bookmarked}`} content={c} />)}</div>{listing.data.items.some(c => c.is_sample) && <p className="sample-notice">‘샘플’ 표시는 기능 체험을 위한 가상 행사입니다. 실제 개최·예매 정보가 아닙니다.</p>}</> : <EmptyState />}
    </section>
    <section className="taste-band"><div className="container taste-band-inner"><div className="taste-mark"><Sparkles size={34} /></div><div><h2>좋아하는 걸 알려주면,<br className="mobile-only" /> 더 좋아할 것을 찾아드려요.</h2><p>취향과 문화생활이 쌓일수록, 추천도 나다워집니다.</p></div><button className="button light" onClick={s.openSurvey}>{s.user?.survey_completed ? '내 취향 다시 고르기' : '내 취향 찾아보기'}<ArrowUpRight size={18} /></button></div></section>
    <section className="container section"><div className="section-heading"><div><h2>{s.user ? `${s.user.name} 님에게 건네는 문화` : '새로운 취향을 위한 발견'}<Sparkles className="heading-icon" size={22} /></h2><p>{s.user ? '관심 분야와 최근 활동을 바탕으로 골랐어요.' : '아직 몰랐던 나의 취향을 만나보세요.'}</p></div><Link to="/recommendations" className="text-link">추천 더 보기<ArrowRight size={17} /></Link></div>
      {recs.loading ? <Loading /> : recs.error ? <ErrorState error={recs.error} retry={recs.retry} /> : recs.data?.items.length ? <div className="card-grid">{recs.data.items.map(c => <ContentCard key={`${c.id}-${c.bookmarked}`} content={c} recommended />)}</div> : <EmptyState title="아직 추천할 콘텐츠가 없어요" text="새 문화정보가 수집되면 이곳에서 만날 수 있어요." />}
    </section>
  </>
}
