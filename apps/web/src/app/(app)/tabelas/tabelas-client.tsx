"use client";

import { useMemo, useState } from "react";
import { Button, Field, PageHeader, Panel } from "@/components/ui";
import {
  GS_TABLES,
  convertDerivados,
  formatPt,
  parseBrNumber,
  type GsTableId,
} from "@/lib/demo/tabelas";

export function TabelasClient() {
  const [tab, setTab] = useState<GsTableId>("derivados");

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Tabelas 20 °C"
        description="Correção volumétrica da GS — derivados de petróleo e álcool. O mesmo módulo do app, em tela de escritório."
      />

      <div className="grid gap-3 lg:grid-cols-3">
        {GS_TABLES.map((table) => (
          <button
            key={table.id}
            type="button"
            onClick={() => setTab(table.id)}
            className={`border p-4 text-left transition ${
              tab === table.id
                ? "border-brass bg-white shadow-[inset_0_3px_0_#c59e39]"
                : "border-line bg-white hover:border-brass/50"
            }`}
          >
            <p className="text-[10px] font-medium uppercase tracking-[0.18em] text-brass">
              {table.standard}
            </p>
            <h2 className="mt-2 font-serif text-lg text-navy">{table.title}</h2>
            <p className="mt-2 text-sm leading-6 text-muted">{table.description}</p>
            <p className="mt-3 truncate text-xs text-navy/45">{table.fileName}</p>
          </button>
        ))}
      </div>

      <div className="mt-6">
        {tab === "derivados" ? <DerivadosPanel /> : null}
        {tab === "alcool" ? <AlcoolPanel /> : null}
        {tab === "validacao" ? <ValidacaoPanel /> : null}
      </div>
    </div>
  );
}

function FileBar({ href, fileName }: { href: string; fileName: string }) {
  return (
    <div className="mb-4 flex flex-wrap items-center justify-between gap-3 border border-line bg-paper px-4 py-3">
      <p className="text-sm text-navy">
        Planilha original · <span className="font-medium">{fileName}</span>
      </p>
      <Button href={href} variant="ghost">
        Baixar arquivo
      </Button>
    </div>
  );
}

function DerivadosPanel() {
  const table = GS_TABLES[0];
  const [densityAmbient, setDensityAmbient] = useState("723");
  const [temperature, setTemperature] = useState("25");
  const [volumeAmbient, setVolumeAmbient] = useState("10000");
  const [temperatureCt, setTemperatureCt] = useState("25");
  const [volumeDanfe, setVolumeDanfe] = useState("9940");

  const result = useMemo(() => {
    const d = parseBrNumber(densityAmbient);
    const t = parseBrNumber(temperature);
    const v = parseBrNumber(volumeAmbient);
    const tc = parseBrNumber(temperatureCt);
    const danfe = parseBrNumber(volumeDanfe);
    if (d == null || t == null || v == null || tc == null || danfe == null) return null;
    return convertDerivados({
      densityAmbient: d,
      temperature: t,
      volumeAmbient: v,
      temperatureCt: tc,
      volumeDanfe: danfe,
    });
  }, [densityAmbient, temperature, volumeAmbient, temperatureCt, volumeDanfe]);

  return (
    <div>
      <FileBar href={table.href} fileName={table.fileName} />
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <h3 className="mb-4 font-serif text-lg text-navy">Amostra</h3>
          <div className="space-y-3">
            <Field
              label="Densidade ambiente (kg/m³)"
              name="damb"
              defaultValue={densityAmbient}
            >
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={densityAmbient}
                onChange={(event) => setDensityAmbient(event.target.value)}
              />
            </Field>
            <Field label="Temperatura (°C)" name="temp" defaultValue={temperature}>
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={temperature}
                onChange={(event) => setTemperature(event.target.value)}
              />
            </Field>
            <Field
              label="Volume ambiente (L)"
              name="vamb"
              defaultValue={volumeAmbient}
            >
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={volumeAmbient}
                onChange={(event) => setVolumeAmbient(event.target.value)}
              />
            </Field>
            <Field
              label="Temperatura do CT (°C)"
              name="tct"
              defaultValue={temperatureCt}
            >
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={temperatureCt}
                onChange={(event) => setTemperatureCt(event.target.value)}
              />
            </Field>
            <Field
              label="Volume a 20 °C — DANFE (L20)"
              name="danfe"
              defaultValue={volumeDanfe}
            >
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={volumeDanfe}
                onChange={(event) => setVolumeDanfe(event.target.value)}
              />
            </Field>
          </div>
        </Panel>
        <Panel>
          <h3 className="mb-4 font-serif text-lg text-navy">Resultado a 20 °C</h3>
          {result ? (
            <dl className="space-y-3 text-sm">
              <ResultRow
                label="Densidade a 20 °C"
                value={`${formatPt(result.density20, 3)} kg/m³`}
              />
              <ResultRow label="Fator de correção (CTL)" value={formatPt(result.ctl, 4)} />
              <ResultRow
                label="Volume a 20 °C"
                value={`${formatPt(result.volume20, 1)} L20`}
              />
              <ResultRow label="Peso" value={`${formatPt(result.weight, 3)} kg`} />
              <ResultRow
                label="Perda & sobra"
                value={`${formatPt(result.variance ?? 0, 1)} L20`}
              />
            </dl>
          ) : (
            <p className="text-sm text-muted">Preencha os campos numéricos da amostra.</p>
          )}
          <p className="mt-6 text-xs leading-5 text-muted">
            Cálculo no sistema a partir das faixas DNS_20 e FCV_20 da planilha GS.
            A planilha original permanece disponível para conferência.
          </p>
        </Panel>
      </div>
    </div>
  );
}

function AlcoolPanel() {
  const table = GS_TABLES[1];
  const [densityAmbient, setDensityAmbient] = useState("800");
  const [temperature, setTemperature] = useState("29,45");
  const [volumeAmbient, setVolumeAmbient] = useState("10000");

  const result = useMemo(() => {
    const d = parseBrNumber(densityAmbient);
    const t = parseBrNumber(temperature);
    const v = parseBrNumber(volumeAmbient);
    if (d == null || t == null || v == null) return null;
    return convertDerivados({
      densityAmbient: d,
      temperature: t,
      volumeAmbient: v,
      temperatureCt: t,
    });
  }, [densityAmbient, temperature, volumeAmbient]);

  return (
    <div>
      <FileBar href={table.href} fileName={table.fileName} />
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <h3 className="mb-1 font-serif text-lg text-navy">Misturas etanol-água</h3>
          <p className="mb-4 text-sm text-muted">NBR 5992 · correção a 20 °C</p>
          <div className="space-y-3">
            <Field label="Densidade ambiente (kg/m³)" name="damb-alc">
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={densityAmbient}
                onChange={(event) => setDensityAmbient(event.target.value)}
              />
            </Field>
            <Field label="Temperatura (°C)" name="temp-alc">
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={temperature}
                onChange={(event) => setTemperature(event.target.value)}
              />
            </Field>
            <Field label="Volume ambiente (L)" name="vamb-alc">
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={volumeAmbient}
                onChange={(event) => setVolumeAmbient(event.target.value)}
              />
            </Field>
          </div>
        </Panel>
        <Panel>
          <h3 className="mb-4 font-serif text-lg text-navy">Resultado a 20 °C</h3>
          {result ? (
            <dl className="space-y-3 text-sm">
              <ResultRow
                label="Densidade a 20 °C"
                value={`${formatPt(result.density20, 2)} kg/m³`}
              />
              <ResultRow label="Fator de correção" value={formatPt(result.ctl, 4)} />
              <ResultRow
                label="Volume a 20 °C"
                value={`${formatPt(result.volume20, 1)} L20`}
              />
            </dl>
          ) : (
            <p className="text-sm text-muted">Preencha densidade, temperatura e volume.</p>
          )}
          <p className="mt-6 text-xs leading-5 text-muted">
            A tabela INPM completa (cerca de 3 mil linhas) está no arquivo Excel.
            Use o download para conferência ponto a ponto.
          </p>
        </Panel>
      </div>
    </div>
  );
}

function ValidacaoPanel() {
  const table = GS_TABLES[2];
  const [product, setProduct] = useState("S10");
  const [volBase, setVolBase] = useState("55548");
  const [densAmostra, setDensAmostra] = useState("872,84");
  const [temp, setTemp] = useState("36,12");
  const [volSistema, setVolSistema] = useState("49880");

  const result = useMemo(() => {
    const vb = parseBrNumber(volBase);
    const d = parseBrNumber(densAmostra);
    const t = parseBrNumber(temp);
    const vs = parseBrNumber(volSistema);
    if (vb == null || d == null || t == null || vs == null) return null;
    const base = convertDerivados({
      densityAmbient: d,
      temperature: t,
      volumeAmbient: vb,
      temperatureCt: t,
    });
    const systemVol20 = vs;
    const varianceLit = systemVol20 - base.volume20;
    const variancePct = base.volume20 === 0 ? 0 : (varianceLit / base.volume20) * 100;
    return { ...base, varianceLit, variancePct, systemVol20 };
  }, [volBase, densAmostra, temp, volSistema]);

  return (
    <div>
      <FileBar href={table.href} fileName={table.fileName} />
      <Panel>
        <h3 className="font-serif text-lg text-navy">Validação da calibração</h3>
        <label className="mt-4 block max-w-xs">
          <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
            Produto
          </span>
          <input
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
            value={product}
            onChange={(event) => setProduct(event.target.value)}
          />
        </label>
      </Panel>
      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Panel>
          <h3 className="mb-4 font-serif text-lg text-navy">Informações da base</h3>
          <div className="space-y-3">
            <Field label="Volume ambiente do CT (L)" name="vol-base">
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={volBase}
                onChange={(event) => setVolBase(event.target.value)}
              />
            </Field>
            <Field label="Densidade da amostra (kg/m³)" name="dens-base">
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={densAmostra}
                onChange={(event) => setDensAmostra(event.target.value)}
              />
            </Field>
            <Field label="Temperatura da amostra / CT (°C)" name="temp-base">
              <input
                className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                value={temp}
                onChange={(event) => setTemp(event.target.value)}
              />
            </Field>
          </div>
        </Panel>
        <Panel>
          <h3 className="mb-4 font-serif text-lg text-navy">Informações do sistema</h3>
          <Field label="Volume ambiente do sistema (kg ou L)" name="vol-sis">
            <input
              className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm outline-none focus:border-brass"
              value={volSistema}
              onChange={(event) => setVolSistema(event.target.value)}
            />
          </Field>
          {result ? (
            <dl className="mt-6 space-y-3 text-sm">
              <ResultRow
                label="Densidade a 20 °C"
                value={`${formatPt(result.density20, 3)} kg/m³`}
              />
              <ResultRow label="Fator CTL" value={formatPt(result.ctl, 4)} />
              <ResultRow
                label="Volume a 20 °C da base"
                value={`${formatPt(result.volume20, 2)} L`}
              />
              <ResultRow
                label="Perda & sobra"
                value={`${formatPt(result.variancePct, 3)} % · ${formatPt(result.varianceLit, 1)} L`}
              />
            </dl>
          ) : null}
        </Panel>
      </div>
    </div>
  );
}

function ResultRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-line pb-2">
      <dt className="text-muted">{label}</dt>
      <dd className="font-medium text-navy">{value}</dd>
    </div>
  );
}
