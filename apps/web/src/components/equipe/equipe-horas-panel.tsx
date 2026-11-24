import Link from "next/link";
import { formatWorkedHours } from "@/lib/campo-data/work-hours";

export type HorasTechChip = {
  name: string;
  email: string;
  login: string;
};

export type HorasRow = {
  osId: string;
  osNumber: string;
  client: string;
  date: string;
  clockIn: string;
  clockOut: string;
  lunchLabel: string;
  minutes: number;
  responsible: string;
};

function formatDatePt(raw: string) {
  const d = new Date(raw);
  if (!Number.isNaN(d.getTime())) {
    return d.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
  }
  return raw || "—";
}

function monthLabel(ym: string) {
  const [y, m] = ym.split("-").map(Number);
  if (!y || !m) return ym;
  const d = new Date(Date.UTC(y, m - 1, 1));
  return d.toLocaleDateString("pt-BR", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  });
}

export function EquipeHorasPanel({
  technicians,
  selectedName,
  month,
  rows,
}: {
  technicians: HorasTechChip[];
  selectedName: string | null;
  month: string;
  rows: HorasRow[];
}) {
  const totalMinutes = rows.reduce((sum, r) => sum + r.minutes, 0);
  const days = new Set(rows.map((r) => r.date).filter(Boolean)).size;
  const osCount = new Set(rows.map((r) => r.osId)).size;
  const avg = days > 0 ? Math.round(totalMinutes / days) : 0;

  const [y, m] = month.split("-").map(Number);
  const prev = new Date(Date.UTC(y, m - 2, 1));
  const next = new Date(Date.UTC(y, m, 1));
  const prevYm = `${prev.getUTCFullYear()}-${String(prev.getUTCMonth() + 1).padStart(2, "0")}`;
  const nextYm = `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, "0")}`;
  const techQ = selectedName
    ? `&tech=${encodeURIComponent(selectedName)}`
    : "";

  return (
    <div className="space-y-5">
      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Banco de horas
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">
          Técnicos de campo
        </h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-navy/60">
          Só quem faz campo (papel técnico/ambos, ativo e aprovado). Soma dos
          RDOs: entrada − almoço − saída — mesma regra do GS Campo.
        </p>

        <div className="mt-4 flex flex-wrap gap-2">
          {technicians.map((user) => {
            const active =
              selectedName &&
              user.name.toLowerCase() === selectedName.toLowerCase();
            return (
              <Link
                key={user.email || user.login}
                href={`/equipe?tab=horas&month=${month}&tech=${encodeURIComponent(user.name)}`}
                className={[
                  "rounded-xl px-3 py-2 text-sm font-medium transition",
                  active
                    ? "bg-navy text-paper"
                    : "border border-navy/15 bg-paper text-navy hover:border-brass/40",
                ].join(" ")}
              >
                {user.name}
              </Link>
            );
          })}
          {technicians.length === 0 ? (
            <p className="text-sm text-muted">
              Nenhum técnico de campo ativo/aprovado.
            </p>
          ) : null}
        </div>
      </section>

      {selectedName ? (
        <>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                {monthLabel(month)}
              </p>
              <h3 className="mt-1 font-serif text-2xl text-navy">
                {selectedName}
              </h3>
            </div>
            <div className="flex flex-wrap gap-2">
              <Link
                href={`/equipe?tab=horas&month=${prevYm}${techQ}`}
                className="rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm font-medium text-navy hover:border-brass/40"
              >
                ← Mês anterior
              </Link>
              <Link
                href={`/equipe?tab=horas&month=${nextYm}${techQ}`}
                className="rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm font-medium text-navy hover:border-brass/40"
              >
                Próximo mês →
              </Link>
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {[
              { label: "Total no mês", value: formatWorkedHours(totalMinutes) },
              { label: "Dias com RDO", value: String(days) },
              { label: "OS", value: String(osCount) },
              {
                label: "Média / dia",
                value: formatWorkedHours(avg),
              },
            ].map((kpi) => (
              <div
                key={kpi.label}
                className="rounded-2xl border border-navy/10 bg-white px-4 py-4 shadow-[0_8px_24px_rgba(12,31,51,0.04)]"
              >
                <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
                  {kpi.label}
                </p>
                <p className="mt-2 font-serif text-3xl text-navy">{kpi.value}</p>
              </div>
            ))}
          </div>

          {rows.length === 0 ? (
            <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
              Nenhum RDO com ponto neste mês para {selectedName}.
            </div>
          ) : (
            <div className="space-y-3">
              {rows.map((row) => (
                <article
                  key={`${row.osId}-${row.date}-${row.clockIn}`}
                  className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-navy/10 bg-white px-4 py-3.5 shadow-[0_6px_20px_rgba(12,31,51,0.04)]"
                >
                  <div className="min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-brass">
                      {formatDatePt(row.date)}
                    </p>
                    <Link
                      href={`/os/${row.osId}/rdo`}
                      className="mt-1 block font-serif text-lg text-navy hover:underline"
                    >
                      GS {row.osNumber}
                    </Link>
                    <p className="mt-0.5 text-sm text-navy/55">
                      {row.client}
                      {row.responsible ? ` · ${row.responsible}` : ""}
                    </p>
                  </div>
                  <div className="flex flex-wrap items-center gap-3 text-sm">
                    <span className="rounded-lg bg-paper px-2.5 py-1.5 text-navy/70">
                      {row.clockIn} → {row.clockOut}
                    </span>
                    {row.lunchLabel ? (
                      <span className="rounded-lg bg-paper px-2.5 py-1.5 text-navy/50">
                        {row.lunchLabel}
                      </span>
                    ) : null}
                    <span className="rounded-xl bg-navy px-3 py-1.5 font-semibold text-brass">
                      {formatWorkedHours(row.minutes)}
                    </span>
                  </div>
                </article>
              ))}
            </div>
          )}
        </>
      ) : null}
    </div>
  );
}
