import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { fetchFeedAlgorithmDashboard } from "@/lib/admin-metrics";

export async function FeedAlgorithmObservability() {
  const metrics = await fetchFeedAlgorithmDashboard(24);
  return (
    <section className="flex flex-col gap-3">
      <div>
        <h2 className="text-sm font-medium">WYNOS Feed Algorithm v{metrics.algorithmVersion}</h2>
        <p className="text-xs text-muted-foreground">ข้อมูลรวม 24 ชั่วโมง · สำหรับการวินิจฉัย ไม่ตัดสินผู้ชนะการทดลองอัตโนมัติ</p>
      </div>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card>
          <CardHeader><CardTitle>Source Performance</CardTitle><CardDescription>Actual delivery, fallback และ similarity origin</CardDescription></CardHeader>
          <CardContent className="space-y-2 text-sm">
            {metrics.sources.map((source) => (
              <div className="flex justify-between" key={source.feed_source}>
                <span>{source.feed_source}</span><span>{source.impressions.toLocaleString("th-TH")} · p95 {Math.round(source.p95_latency_ms ?? 0)}ms</span>
              </div>
            ))}
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>Trending / Top100</CardTitle><CardDescription>ตรวจความแตกต่างของสองระบบ authoritative</CardDescription></CardHeader>
          <CardContent className="space-y-2 text-sm">
            <p>Trending candidates: {metrics.trending.candidate_count}</p>
            <p>Top100 candidates: {metrics.top100.candidate_count}</p>
            <p>Top20 overlap: {metrics.trendingTop100.overlap_top20}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>Cold Start / Experiments</CardTitle><CardDescription>Aggregate cohorts เท่านั้น ไม่มี affinity รายบุคคล</CardDescription></CardHeader>
          <CardContent className="text-sm">{metrics.maturity.map((row) => <p key={row.maturity_state}>{row.maturity_state}: {row.impressions}</p>)}</CardContent>
        </Card>
      </div>
    </section>
  );
}
