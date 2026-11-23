import type { StatusSlice } from "./types";

export function StatusChart({ slices }: { slices: StatusSlice[] }) {
  const totalCount = slices.reduce((sum, s) => sum + s.count, 0);
  const total = totalCount || 1;
  const size = 168;
  const stroke = 18;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;

  let offset = 0;
  const arcs = slices.map((slice) => {
    const length = (slice.count / total) * circumference;
    const arc = { ...slice, length, offset };
    offset += length;
    return arc;
  });

  return (
    <div className="flex flex-col gap-5 sm:flex-row sm:items-center">
      <div className="relative mx-auto shrink-0">
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="-rotate-90">
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke="rgba(12,31,51,0.08)"
            strokeWidth={stroke}
          />
          {arcs.map((arc) =>
            arc.count === 0 ? null : (
              <circle
                key={arc.key}
                cx={size / 2}
                cy={size / 2}
                r={radius}
                fill="none"
                stroke={arc.color}
                strokeWidth={stroke}
                strokeDasharray={`${arc.length} ${circumference - arc.length}`}
                strokeDashoffset={-arc.offset}
                strokeLinecap="butt"
              />
            ),
          )}
        </svg>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <p className="font-serif text-3xl text-navy">{totalCount}</p>
          <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-navy/45">
            OS
          </p>
        </div>
      </div>

      <ul className="min-w-0 flex-1 space-y-2.5">
        {slices.map((slice) => {
          const pct = totalCount === 0 ? 0 : Math.round((slice.count / total) * 100);
          return (
            <li key={slice.key}>
              <div className="mb-1 flex items-center justify-between gap-2 text-sm">
                <span className="flex items-center gap-2 text-navy/80">
                  <span
                    className="inline-block size-2.5 rounded-full"
                    style={{ background: slice.color }}
                  />
                  {slice.label}
                </span>
                <span className="tabular-nums text-navy/55">
                  {slice.count}
                  <span className="ml-1 text-navy/35">· {pct}%</span>
                </span>
              </div>
              <div className="h-1.5 overflow-hidden rounded-full bg-navy/8">
                <div
                  className="h-full rounded-full transition-[width] duration-500"
                  style={{
                    width: `${pct}%`,
                    background: slice.color,
                  }}
                />
              </div>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
