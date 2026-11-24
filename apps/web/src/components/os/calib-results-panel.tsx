import type { CalibResultsSummary } from "@/lib/campo-data/calib-results";

export function CalibResultsPanel({
  summary,
}: {
  summary: CalibResultsSummary;
}) {
  if (!summary.hasAny) return null;

  return (
    <section className="print-sheet space-y-4">
      {(summary.kFactorFound ||
        summary.kFactorLeft ||
        summary.uncertainty ||
        summary.coverageFactor) && (
        <div className="rounded-3xl border border-navy/10 bg-white p-6">
          <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Resultados
          </h3>
          <dl className="mt-4 grid gap-4 sm:grid-cols-2">
            {summary.kFactorFound ? (
              <div>
                <dt className="text-[11px] uppercase tracking-wide text-navy/45">
                  Fator K encontrado
                </dt>
                <dd className="mt-1 text-sm font-medium text-navy">
                  {summary.kFactorFound}
                </dd>
              </div>
            ) : null}
            {summary.kFactorLeft ? (
              <div>
                <dt className="text-[11px] uppercase tracking-wide text-navy/45">
                  Fator K deixado
                </dt>
                <dd className="mt-1 text-sm font-medium text-navy">
                  {summary.kFactorLeft}
                </dd>
              </div>
            ) : null}
            {summary.uncertainty ? (
              <div>
                <dt className="text-[11px] uppercase tracking-wide text-navy/45">
                  Incerteza
                </dt>
                <dd className="mt-1 text-sm font-medium text-navy">
                  {summary.uncertainty}
                </dd>
              </div>
            ) : null}
            {summary.coverageFactor ? (
              <div>
                <dt className="text-[11px] uppercase tracking-wide text-navy/45">
                  Fator de cobertura
                </dt>
                <dd className="mt-1 text-sm font-medium text-navy">
                  {summary.coverageFactor}
                </dd>
              </div>
            ) : null}
          </dl>
        </div>
      )}

      {summary.flowPoints.length > 0 ? (
        <div className="overflow-x-auto rounded-3xl border border-navy/10 bg-white p-6">
          <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Pontos de vazão
          </h3>
          <table className="mt-4 w-full min-w-[520px] text-left text-sm">
            <thead>
              <tr className="border-b border-navy/10 text-[11px] uppercase tracking-wide text-navy/45">
                <th className="py-2 pr-3 font-medium">Ponto</th>
                <th className="py-2 pr-3 font-medium">Vazão</th>
                <th className="py-2 pr-3 font-medium">Fator antigo</th>
                <th className="py-2 pr-3 font-medium">Verificação</th>
                <th className="py-2 font-medium">Conferências</th>
              </tr>
            </thead>
            <tbody>
              {summary.flowPoints.map((row) => (
                <tr key={row.id} className="border-b border-navy/5 text-navy">
                  <td className="py-2.5 pr-3 font-medium">{row.label}</td>
                  <td className="py-2.5 pr-3">{row.flowRate}</td>
                  <td className="py-2.5 pr-3">{row.oldMeterFactor}</td>
                  <td className="py-2.5 pr-3">{row.verificationRuns}</td>
                  <td className="py-2.5">{row.conferenceRuns}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}

      {summary.genericPoints.length > 0 ? (
        <div className="overflow-x-auto rounded-3xl border border-navy/10 bg-white p-6">
          <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Pontos genéricos
          </h3>
          <table className="mt-4 w-full min-w-[520px] text-left text-sm">
            <thead>
              <tr className="border-b border-navy/10 text-[11px] uppercase tracking-wide text-navy/45">
                <th className="py-2 pr-3 font-medium">Ponto</th>
                <th className="py-2 pr-3 font-medium">Fator antigo</th>
                <th className="py-2 pr-3 font-medium">Novo valor</th>
                <th className="py-2 font-medium">Ciclos</th>
              </tr>
            </thead>
            <tbody>
              {summary.genericPoints.map((row) => (
                <tr key={row.id} className="border-b border-navy/5 text-navy">
                  <td className="py-2.5 pr-3 font-medium">{row.label}</td>
                  <td className="py-2.5 pr-3">{row.oldFactor}</td>
                  <td className="py-2.5 pr-3">{row.newValue}</td>
                  <td className="py-2.5">
                    {row.cyclesFilled}/{row.cyclesTotal}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}
    </section>
  );
}
