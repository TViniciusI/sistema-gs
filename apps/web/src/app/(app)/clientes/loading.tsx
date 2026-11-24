export default function ClientesLoading() {
  return (
    <div className="animate-pulse space-y-5" aria-busy="true">
      <div className="h-8 w-48 rounded bg-navy/10" />
      <div className="h-11 w-full rounded-xl bg-navy/5" />
      <div className="grid gap-3 lg:grid-cols-2">
        {Array.from({ length: 4 }).map((_, i) => (
          <div
            key={i}
            className="h-40 rounded-3xl border border-navy/10 bg-white"
          />
        ))}
      </div>
    </div>
  );
}
