import { formatChangeMeta } from "@/lib/campo-data";

export function ChangeMeta({
  raw,
  className = "",
}: {
  raw?: Record<string, unknown> | null;
  className?: string;
}) {
  const meta = formatChangeMeta(raw);
  if (!meta) return null;
  const when = meta.at
    ? new Date(meta.at).toLocaleString("pt-BR", {
        timeZone: "America/Sao_Paulo",
      })
    : null;
  const source =
    meta.source === "escritorio"
      ? "escritório"
      : meta.source === "campo"
        ? "app"
        : meta.source;

  return (
    <p className={`text-xs text-navy/50 ${className}`.trim()}>
      Última alteração por <span className="font-medium text-navy/70">{meta.name}</span>
      {when ? ` · ${when}` : ""}
      {source ? ` · ${source}` : ""}
    </p>
  );
}
