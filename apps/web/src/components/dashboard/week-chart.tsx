import type { WeekBucket } from "./types";

export function WeekChart({ buckets }: { buckets: WeekBucket[] }) {
  const max = Math.max(1, ...buckets.map((b) => b.count));

  return (
    <div className="flex h-[200px] items-end gap-2 sm:gap-3">
      {buckets.map((bucket) => {
        const height = Math.max(bucket.count === 0 ? 4 : 12, (bucket.count / max) * 160);
        const isPeak = bucket.count > 0 && bucket.count === max;
        return (
          <div key={bucket.key} className="flex min-w-0 flex-1 flex-col items-center gap-2">
            <span className="text-[11px] font-semibold tabular-nums text-navy/55">
              {bucket.count || ""}
            </span>
            <div
              className={[
                "w-full max-w-[42px] rounded-t-lg shadow-[inset_0_1px_0_rgba(255,255,255,0.12)]",
                isPeak
                  ? "bg-gradient-to-t from-navy to-brass"
                  : "bg-gradient-to-t from-navy to-navy-2",
              ].join(" ")}
              style={{ height }}
              title={`${bucket.label}: ${bucket.count}`}
            >
              <div
                className="mx-auto h-1 w-3/5 rounded-full bg-brass/90"
                style={{ marginTop: 6 }}
              />
            </div>
            <span className="truncate text-[10px] font-medium uppercase tracking-wide text-navy/45">
              {bucket.label}
            </span>
          </div>
        );
      })}
    </div>
  );
}
