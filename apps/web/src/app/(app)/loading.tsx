export default function AppLoading() {
  return (
    <div className="animate-pulse space-y-6" aria-hidden>
      <div className="space-y-2">
        <div className="h-7 w-48 rounded bg-line/80" />
        <div className="h-4 w-80 max-w-full rounded bg-line/50" />
      </div>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <div className="h-28 rounded-xl border border-line bg-white" />
        <div className="h-28 rounded-xl border border-line bg-white" />
        <div className="h-28 rounded-xl border border-line bg-white" />
      </div>
      <div className="h-64 rounded-xl border border-line bg-white" />
    </div>
  );
}
