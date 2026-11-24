export default function DocumentosLoading() {
  return (
    <div className="animate-pulse space-y-5" aria-busy="true">
      <div className="space-y-2">
        <div className="h-3 w-28 rounded bg-navy/10" />
        <div className="h-8 w-52 rounded bg-navy/10" />
        <div className="h-4 w-64 max-w-full rounded bg-navy/5" />
      </div>
      <div className="space-y-3">
        {Array.from({ length: 5 }).map((_, i) => (
          <div
            key={i}
            className="h-16 rounded-2xl border border-navy/10 bg-white"
          />
        ))}
      </div>
    </div>
  );
}
