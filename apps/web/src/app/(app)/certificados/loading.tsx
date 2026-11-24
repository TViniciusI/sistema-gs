export default function CertificadosLoading() {
  return (
    <div className="animate-pulse space-y-5" aria-busy="true">
      <div className="space-y-2">
        <div className="h-3 w-28 rounded bg-navy/10" />
        <div className="h-8 w-56 rounded bg-navy/10" />
        <div className="h-4 w-80 max-w-full rounded bg-navy/5" />
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div
            key={i}
            className="h-36 rounded-3xl border border-navy/10 bg-white"
          />
        ))}
      </div>
    </div>
  );
}
