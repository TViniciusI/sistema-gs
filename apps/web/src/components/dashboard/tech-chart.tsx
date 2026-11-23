import type { TechLoad } from "./types";

export function TechChart({ rows }: { rows: TechLoad[] }) {
  const max = Math.max(1, ...rows.map((r) => r.count));

  if (rows.length === 0) {
    return (
      <p className="py-8 text-center text-sm text-muted">
        Sem técnicos vinculados às OS abertas.
      </p>
    );
  }

  return (
    <ul className="space-y-3">
      {rows.map((row, index) => (
        <li key={row.name} className="grid grid-cols-[1.4fr_2fr_auto] items-center gap-3">
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-navy">{row.name}</p>
            <p className="text-[11px] text-navy/40">#{index + 1}</p>
          </div>
          <div className="h-2.5 overflow-hidden rounded-full bg-navy/8">
            <div
              className="h-full rounded-full bg-gradient-to-r from-brass to-brass-2"
              style={{ width: `${(row.count / max) * 100}%` }}
            />
          </div>
          <span className="tabular-nums text-sm font-semibold text-navy">
            {row.count}
          </span>
        </li>
      ))}
    </ul>
  );
}
