export default function CalibracaoLoading() {
  return (
    <div className="animate-pulse space-y-5" aria-busy="true">
      <div className="h-8 w-52 rounded bg-navy/10" />
      <div className="grid gap-3 sm:grid-cols-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="h-24 rounded-2xl border border-navy/10 bg-white" />
        ))}
      </div>
      <div className="grid gap-3 lg:grid-cols-2">
        {Array.from({ length: 4 }).map((_, i) => (
          <div
            key={i}
            className="h-36 rounded-3xl border border-navy/10 bg-white"
          />
        ))}
      </div>
    </div>
  );
}
