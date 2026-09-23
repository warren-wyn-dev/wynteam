import { QuoteFeedCard } from "@/components/quote-feed-card";
import type { HomeFeedRow } from "@/lib/feed";
import type { QuoteEngagement } from "@/lib/quote-actions";

const row: HomeFeedRow = {
  id: "d1000000-0000-0000-0000-000000000001",
  content_type: "drop",
  author_id: "11111111-1111-1111-1111-111111111111",
  author_username: "original",
  author_display_name: "Original post",
  created_at: "2026-09-23T01:00:00.000Z",
  caption: "นี่คือ WYNOS",
  image_url: null,
  like_count: 4,
  comment_count: 2,
  redrop_count: 1,
  redrop_id: "a1000000-0000-0000-0000-000000000001",
  redropper_id: "22222222-2222-2222-2222-222222222222",
  redropper_username: "quote_author",
  redropper_display_name: "Quote author",
  quote_text: "สวย",
};
const zero: QuoteEngagement = {
  quoteId: "a1000000-0000-0000-0000-000000000001",
  likeCount: 0,
  commentCount: 0,
  redropCount: 0,
  liked: false,
  saved: false,
  redropped: false,
};

export default function QuoteFixture() {
  return (
    <main className="wyn-home-feed" data-testid="quote-fixture" style={{ maxWidth: 440, margin: "0 auto" }}>
      <QuoteFeedCard row={row} viewerId="" initialQuoteState={zero} />
    </main>
  );
}
