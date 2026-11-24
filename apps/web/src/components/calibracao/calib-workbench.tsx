import {
  formatCalibNumber,
  formatPercent,
  type CalibWorkbench,
} from "@/lib/campo-data/calib-results";

function Field({ label, value }: { label: string; value?: string }) {
  const v = (value || "").trim();
  if (!v) return null;
  return (
    <div className="rounded-2xl bg-paper px-4 py-3">
      <p className="text-[10px] uppercase tracking-wide text-navy/45">{label}</p>
      <p className="mt-1 text-sm font-medium text-navy">{v}</p>
    </div>
  );
}

export function CalibWorkbenchView({ data }: { data: CalibWorkbench }) {
  return (
    <div className="space-y-5">
      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Instrumento e condições
        </p>
        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Field label="Cliente" value={data.clientName} />
          <Field label="TAG" value={data.equipmentTag} />
          <Field label="Tipo" value={data.equipmentType || data.kind} />
          <Field
            label="Fabricante / modelo"
            value={[data.manufacturer, data.model].filter(Boolean).join(" · ")}
          />
          <Field label="N/S" value={data.serialNumber} />
          <Field label="Técnico" value={data.technicianName} />
          <Field label="Local" value={data.site} />
          <Field label="Procedimento" value={data.procedure} />
          <Field label="Calibrado em" value={data.calibrationDate} />
          <Field label="Próxima" value={data.nextCalibrationDate} />
          <Field
            label="Ambiente"
            value={[
              data.ambientTemp && `${data.ambientTemp} °C`,
              data.humidity && `${data.humidity} %UR`,
              data.pressure && `${data.pressure}`,
            ]
              .filter(Boolean)
              .join(" · ")}
          />
          <Field
            label="Fluido"
            value={[
              data.fluid,
              data.fluidDensity && `ρ ${data.fluidDensity}`,
              data.fluidViscosity && `μ ${data.fluidViscosity}`,
              data.productTemperature && `${data.productTemperature} °C`,
            ]
              .filter(Boolean)
              .join(" · ")}
          />
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Resultados
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">
          Fator K, incerteza e cobertura
        </h2>
        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl border border-navy/10 bg-paper px-4 py-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
              Fator K encontrado
            </p>
            <p className="mt-2 font-serif text-2xl text-navy">
              {data.meterKFactorFound || "—"}
            </p>
          </div>
          <div className="rounded-2xl border border-navy/10 bg-paper px-4 py-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
              Fator K deixado
            </p>
            <p className="mt-2 font-serif text-2xl text-navy">
              {data.meterKFactorLeft || "—"}
            </p>
          </div>
          <div className="rounded-2xl border border-navy/10 bg-paper px-4 py-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
              Incerteza expandida
            </p>
            <p className="mt-2 font-serif text-2xl text-navy">
              {data.measurementUncertainty
                ? data.measurementUncertainty.includes("%")
                  ? data.measurementUncertainty
                  : `${data.measurementUncertainty} %`
                : "—"}
            </p>
          </div>
          <div className="rounded-2xl border border-navy/10 bg-paper px-4 py-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
              k / ν_eff
            </p>
            <p className="mt-2 font-serif text-2xl text-navy">
              {[data.coverageFactor && `k=${data.coverageFactor}`, data.effectiveDof && `ν=${data.effectiveDof}`]
                .filter(Boolean)
                .join(" · ") || "—"}
            </p>
          </div>
        </div>
        {data.linearityPct != null ? (
          <p className="mt-3 text-sm text-navy/55">
            Linearidade entre vazões:{" "}
            <span className="font-semibold text-navy">
              {formatPercent(data.linearityPct, 3)}
            </span>
          </p>
        ) : null}
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Padrões utilizados
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">
          Referências da calibração
        </h2>
        {data.standards.length === 0 ? (
          <p className="mt-4 rounded-2xl border border-dashed border-navy/15 px-4 py-8 text-center text-sm text-muted">
            Nenhum padrão embutido neste job.
          </p>
        ) : (
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            {data.standards.map((std) => (
              <article
                key={std.id}
                className="rounded-2xl border border-navy/10 bg-paper/70 px-4 py-3.5"
              >
                <p className="font-serif text-lg text-navy">
                  {std.tag || "Padrão"}
                </p>
                <p className="mt-1 text-sm text-navy/55">
                  {[std.description, std.manufacturer, std.model]
                    .filter(Boolean)
                    .join(" · ") || "—"}
                </p>
                <p className="mt-2 text-xs text-navy/45">
                  {[
                    std.serialNumber && `N/S ${std.serialNumber}`,
                    std.certificate && `Cert. ${std.certificate}`,
                    std.validity && `Val. ${std.validity}`,
                    std.uncertainty &&
                      `U ${
                        std.uncertainty.startsWith("±")
                          ? std.uncertainty
                          : `±${std.uncertainty}`
                      }`,
                    std.coverageK && `k=${std.coverageK}`,
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                </p>
              </article>
            ))}
          </div>
        )}
      </section>

      {data.flowDetails.length > 0 ? (
        <section className="space-y-4">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Pontos de vazão
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Corridas, Mf e repetibilidade
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              Mf = volume padrão / volume do instrumento (mesma regra do GS
              Campo).
            </p>
          </div>
          {data.flowDetails.map((point) => (
            <article
              key={point.id}
              className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6"
            >
              <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                  <h3 className="font-serif text-xl text-navy">{point.label}</h3>
                  <p className="mt-1 text-sm text-navy/55">
                    Vazão{" "}
                    {point.flowRate == null
                      ? "—"
                      : `${formatCalibNumber(point.flowRate, 2)} ${point.flowUnit}`}
                    {" · "}Mf antigo{" "}
                    {formatCalibNumber(point.oldMeterFactor, 6)}
                  </p>
                </div>
                <div className="flex flex-wrap gap-2 text-sm">
                  <span className="rounded-xl bg-paper px-3 py-1.5 text-navy/70">
                    Mf médio {formatCalibNumber(point.meanMf, 6)}
                  </span>
                  <span className="rounded-xl bg-paper px-3 py-1.5 text-navy/70">
                    Rep. {formatPercent(point.repeatabilityPct, 3)}
                  </span>
                  <span className="rounded-xl bg-navy px-3 py-1.5 font-semibold text-brass">
                    Novo {formatCalibNumber(point.suggestedFactor, 6)}
                  </span>
                  {point.conferenceRuns > 0 ? (
                    <span className="rounded-xl border border-navy/15 px-3 py-1.5 text-navy/55">
                      {point.conferenceRuns} conf.
                    </span>
                  ) : null}
                </div>
              </div>

              {point.verification.length === 0 ? (
                <p className="mt-4 text-sm text-muted">
                  Sem corridas de verificação preenchidas.
                </p>
              ) : (
                <div className="mt-4 overflow-x-auto">
                  <table className="w-full min-w-[640px] text-left text-sm">
                    <thead>
                      <tr className="border-b border-navy/10 text-[11px] uppercase tracking-wide text-navy/45">
                        <th className="py-2 pr-3 font-medium">#</th>
                        <th className="py-2 pr-3 font-medium">Padrão</th>
                        <th className="py-2 pr-3 font-medium">Instrumento</th>
                        <th className="py-2 pr-3 font-medium">ρ</th>
                        <th className="py-2 pr-3 font-medium">T</th>
                        <th className="py-2 pr-3 font-medium">Mf</th>
                        <th className="py-2 font-medium">Erro %</th>
                      </tr>
                    </thead>
                    <tbody>
                      {point.verification.map((run, i) => (
                        <tr
                          key={run.id}
                          className="border-b border-navy/5 text-navy"
                        >
                          <td className="py-2.5 pr-3 font-medium">{i + 1}</td>
                          <td className="py-2.5 pr-3">
                            {formatCalibNumber(run.standardVolume, 4)}
                          </td>
                          <td className="py-2.5 pr-3">
                            {formatCalibNumber(run.objectVolume, 4)}
                          </td>
                          <td className="py-2.5 pr-3">
                            {formatCalibNumber(run.density, 4)}
                          </td>
                          <td className="py-2.5 pr-3">
                            {formatCalibNumber(run.temperature, 2)}
                          </td>
                          <td className="py-2.5 pr-3 font-semibold">
                            {formatCalibNumber(run.meterFactor, 6)}
                          </td>
                          <td className="py-2.5">
                            {formatPercent(run.errorPct, 3)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </article>
          ))}
        </section>
      ) : null}

      {data.genericPoints.length > 0 ? (
        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Pontos genéricos
          </p>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[480px] text-left text-sm">
              <thead>
                <tr className="border-b border-navy/10 text-[11px] uppercase tracking-wide text-navy/45">
                  <th className="py-2 pr-3 font-medium">Ponto</th>
                  <th className="py-2 pr-3 font-medium">Fator antigo</th>
                  <th className="py-2 pr-3 font-medium">Novo valor</th>
                  <th className="py-2 font-medium">Ciclos</th>
                </tr>
              </thead>
              <tbody>
                {data.genericPoints.map((row) => (
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
        </section>
      ) : null}
    </div>
  );
}
