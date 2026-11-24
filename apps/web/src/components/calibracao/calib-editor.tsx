"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState, useTransition } from "react";
import { saveCalibracaoAction } from "@/app/(app)/calibracao/actions";
import {
  buildCalibrationWorkbench,
  correctedMeterFactor,
  formatCalibNumber,
  formatPercent,
  meanOf,
  meterFactor,
  parseCalibNumber,
  repeatabilityPercent,
  volumetricErrorPercent,
} from "@/lib/campo-data";
import type { CampoStandard } from "@/lib/campo-data";

const inputClass =
  "mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm text-navy outline-none focus:border-brass";

const KINDS = [
  { value: "volumetric", label: "Volumétrica" },
  { value: "volumetricInverted", label: "Volumétrica invertida" },
  { value: "temperature", label: "Temperatura" },
  { value: "temperatureMesh", label: "Malha / PT100" },
  { value: "density", label: "Densidade" },
  { value: "pressure", label: "Pressão" },
  { value: "conductivity", label: "Condutividade" },
  { value: "telemetry", label: "Telemetria" },
];

const STATUSES = [
  { value: "draft", label: "Rascunho" },
  { value: "inProgress", label: "Em andamento" },
  { value: "pendingReview", label: "Em revisão" },
  { value: "done", label: "Concluída" },
];

type RunDraft = {
  id: string;
  standardVolume: string;
  objectVolume: string;
  density: string;
  temperature: string;
};

type PointDraft = {
  id: string;
  flowRate: string;
  flowUnit: string;
  oldMeterFactor: string;
  verification: RunDraft[];
};

type StandardDraft = {
  id: string;
  tag: string;
  description: string;
  certificate: string;
  validity: string;
  uncertainty: string;
  coverageK: string;
  serialNumber: string;
  manufacturer: string;
  model: string;
};

function newId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

function emptyRun(): RunDraft {
  return {
    id: newId("run"),
    standardVolume: "",
    objectVolume: "",
    density: "",
    temperature: "",
  };
}

function emptyPoint(): PointDraft {
  return {
    id: newId("pt"),
    flowRate: "",
    flowUnit: "L/min",
    oldMeterFactor: "",
    verification: [emptyRun(), emptyRun(), emptyRun()],
  };
}

function text(v: unknown) {
  return String(v ?? "").trim();
}

function runsFromRaw(raw: unknown): RunDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    return [emptyRun(), emptyRun(), emptyRun()];
  }
  return raw.map((item, i) => {
    const r =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(r.id) || newId(`run${i}`),
      standardVolume: String(
        r.standardVolume ?? r.standard ?? r.padrao ?? "",
      ),
      objectVolume: String(
        r.objectVolume ?? r.meterVolume ?? r.instrument ?? "",
      ),
      density: String(r.density ?? ""),
      temperature: String(r.temperature ?? ""),
    };
  });
}

function pointsFromRaw(raw: unknown): PointDraft[] {
  if (!Array.isArray(raw) || raw.length === 0) return [emptyPoint()];
  return raw.map((item, i) => {
    const p =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(p.id) || newId(`pt${i}`),
      flowRate: String(p.flowRate ?? ""),
      flowUnit: text(p.flowUnit) || "L/min",
      oldMeterFactor: String(p.oldMeterFactor ?? ""),
      verification: runsFromRaw(p.verification),
    };
  });
}

function standardsFromRaw(raw: unknown): StandardDraft[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((item, i) => {
    const s =
      item && typeof item === "object"
        ? (item as Record<string, unknown>)
        : {};
    return {
      id: text(s.id) || newId(`std${i}`),
      tag: text(s.tag) || text(s.name),
      description: text(s.description) || text(s.type),
      certificate: text(s.certificate),
      validity: text(s.validity),
      uncertainty: text(s.uncertainty),
      coverageK: text(s.coverageK) || text(s.coverageFactor),
      serialNumber: text(s.serialNumber) || text(s.serial),
      manufacturer: text(s.manufacturer),
      model: text(s.model),
    };
  });
}

function buildPayload(input: {
  base: Record<string, unknown>;
  id: string;
  number: string;
  kind: string;
  status: string;
  clientName: string;
  equipmentTag: string;
  equipmentType: string;
  manufacturer: string;
  model: string;
  serialNumber: string;
  technicianName: string;
  calibrationDate: string;
  nextCalibrationDate: string;
  site: string;
  fluid: string;
  ambientTemp: string;
  humidity: string;
  pressure: string;
  meterKFactorFound: string;
  meterKFactorLeft: string;
  measurementUncertainty: string;
  coverageFactor: string;
  effectiveDof: string;
  points: PointDraft[];
  standards: StandardDraft[];
}): Record<string, unknown> {
  const inverted = input.kind === "volumetricInverted";
  const points = input.points.map((pt) => {
    const verification = pt.verification
      .filter((r) => r.standardVolume || r.objectVolume)
      .map((r) => {
        const standardVolume = parseCalibNumber(r.standardVolume);
        const objectVolume = parseCalibNumber(r.objectVolume);
        return {
          id: r.id,
          standardVolume,
          objectVolume,
          meterVolume: objectVolume,
          density: parseCalibNumber(r.density),
          temperature: parseCalibNumber(r.temperature),
          isFilled: standardVolume != null || objectVolume != null,
        };
      });
    return {
      id: pt.id,
      flowRate: parseCalibNumber(pt.flowRate),
      flowUnit: pt.flowUnit || "L/min",
      oldMeterFactor: parseCalibNumber(pt.oldMeterFactor),
      verification,
      conferences: [],
    };
  });

  return {
    ...input.base,
    id: input.id,
    number: input.number,
    kind: input.kind,
    status: input.status,
    clientName: input.clientName,
    equipmentTag: input.equipmentTag,
    equipmentType: input.equipmentType,
    manufacturer: input.manufacturer,
    model: input.model,
    serialNumber: input.serialNumber,
    technicianName: input.technicianName,
    fieldTechnicianName: input.technicianName,
    calibrationDate: input.calibrationDate,
    nextCalibrationDate: input.nextCalibrationDate,
    site: input.site,
    fluid: input.fluid,
    ambientTemp: input.ambientTemp,
    humidity: input.humidity,
    pressure: input.pressure,
    meterKFactorFound: input.meterKFactorFound,
    meterKFactorLeft: input.meterKFactorLeft,
    measurementUncertainty: input.measurementUncertainty,
    coverageFactor: input.coverageFactor,
    effectiveDof: input.effectiveDof,
    points,
    standards: input.standards.map((s) => ({
      id: s.id,
      tag: s.tag,
      description: s.description,
      certificate: s.certificate,
      validity: s.validity,
      uncertainty: s.uncertainty,
      coverageK: s.coverageK,
      serialNumber: s.serialNumber,
      manufacturer: s.manufacturer,
      model: s.model,
    })),
    flowCount: points.length,
    runCount: points.reduce((n, p) => n + p.verification.length, 0),
    // hint for math consumers
    _invertedMeterFactor: inverted,
  };
}

export function CalibEditor({
  initial,
  catalogStandards,
  isNew = false,
}: {
  initial: Record<string, unknown>;
  catalogStandards: CampoStandard[];
  isNew?: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  const [id] = useState(text(initial.id) || `calib-${Date.now()}`);
  const [number, setNumber] = useState(text(initial.number));
  const [kind, setKind] = useState(text(initial.kind) || "volumetric");
  const [status, setStatus] = useState(text(initial.status) || "draft");
  const [clientName, setClientName] = useState(text(initial.clientName));
  const [equipmentTag, setEquipmentTag] = useState(text(initial.equipmentTag));
  const [equipmentType, setEquipmentType] = useState(
    text(initial.equipmentType),
  );
  const [manufacturer, setManufacturer] = useState(text(initial.manufacturer));
  const [model, setModel] = useState(text(initial.model));
  const [serialNumber, setSerialNumber] = useState(text(initial.serialNumber));
  const [technicianName, setTechnicianName] = useState(
    text(initial.technicianName) || text(initial.fieldTechnicianName),
  );
  const [calibrationDate, setCalibrationDate] = useState(
    text(initial.calibrationDate),
  );
  const [nextCalibrationDate, setNextCalibrationDate] = useState(
    text(initial.nextCalibrationDate),
  );
  const [site, setSite] = useState(text(initial.site));
  const [fluid, setFluid] = useState(text(initial.fluid));
  const [ambientTemp, setAmbientTemp] = useState(text(initial.ambientTemp));
  const [humidity, setHumidity] = useState(text(initial.humidity));
  const [pressure, setPressure] = useState(text(initial.pressure));
  const [meterKFactorFound, setMeterKFactorFound] = useState(
    text(initial.meterKFactorFound) || text(initial.meterKFactor),
  );
  const [meterKFactorLeft, setMeterKFactorLeft] = useState(
    text(initial.meterKFactorLeft),
  );
  const [measurementUncertainty, setMeasurementUncertainty] = useState(
    text(initial.measurementUncertainty),
  );
  const [coverageFactor, setCoverageFactor] = useState(
    text(initial.coverageFactor),
  );
  const [effectiveDof, setEffectiveDof] = useState(text(initial.effectiveDof));
  const [points, setPoints] = useState<PointDraft[]>(() =>
    pointsFromRaw(initial.points),
  );
  const [standards, setStandards] = useState<StandardDraft[]>(() =>
    standardsFromRaw(initial.standards),
  );

  const inverted = kind === "volumetricInverted";

  const livePayload = useMemo(
    () =>
      buildPayload({
        base: initial,
        id,
        number,
        kind,
        status,
        clientName,
        equipmentTag,
        equipmentType,
        manufacturer,
        model,
        serialNumber,
        technicianName,
        calibrationDate,
        nextCalibrationDate,
        site,
        fluid,
        ambientTemp,
        humidity,
        pressure,
        meterKFactorFound,
        meterKFactorLeft,
        measurementUncertainty,
        coverageFactor,
        effectiveDof,
        points,
        standards,
      }),
    [
      initial,
      id,
      number,
      kind,
      status,
      clientName,
      equipmentTag,
      equipmentType,
      manufacturer,
      model,
      serialNumber,
      technicianName,
      calibrationDate,
      nextCalibrationDate,
      site,
      fluid,
      ambientTemp,
      humidity,
      pressure,
      meterKFactorFound,
      meterKFactorLeft,
      measurementUncertainty,
      coverageFactor,
      effectiveDof,
      points,
      standards,
    ],
  );

  const preview = useMemo(
    () => buildCalibrationWorkbench(livePayload),
    [livePayload],
  );

  function updatePoint(index: number, patch: Partial<PointDraft>) {
    setPoints((prev) =>
      prev.map((p, i) => (i === index ? { ...p, ...patch } : p)),
    );
  }

  function updateRun(
    pointIndex: number,
    runIndex: number,
    patch: Partial<RunDraft>,
  ) {
    setPoints((prev) =>
      prev.map((p, i) => {
        if (i !== pointIndex) return p;
        return {
          ...p,
          verification: p.verification.map((r, j) =>
            j === runIndex ? { ...r, ...patch } : r,
          ),
        };
      }),
    );
  }

  function addCatalogStandard(std: CampoStandard) {
    setStandards((prev) => {
      if (prev.some((s) => s.serialNumber && s.serialNumber === std.serial)) {
        return prev;
      }
      return [
        ...prev,
        {
          id: newId("std"),
          tag: std.name,
          description: std.type,
          certificate: std.certificate,
          validity: std.validity,
          uncertainty: text(std.raw.uncertainty) || "",
          coverageK: text(std.raw.coverageK) || "",
          serialNumber: std.serial,
          manufacturer: "",
          model: "",
        },
      ];
    });
  }

  return (
    <form
      className="space-y-5"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setOk(false);
        startTransition(async () => {
          const result = await saveCalibracaoAction({
            id,
            number,
            kind,
            clientName,
            payload: livePayload,
          });
          if (!result.ok) {
            setError(result.error || "Falha ao salvar.");
            return;
          }
          setOk(true);
          if (isNew && result.id) {
            router.push(`/calibracao/${result.id}`);
          }
          router.refresh();
        });
      }}
    >
      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Cadastro
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Dados do certificado
            </h2>
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="submit"
              disabled={pending || !number.trim()}
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
            >
              {pending ? "Salvando na planilha…" : "Salvar (app + escritório)"}
            </button>
            <Link
              href="/calibracao"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar
            </Link>
          </div>
        </div>
        {error ? <p className="mt-3 text-sm text-red-700">{error}</p> : null}
        {ok ? (
          <p className="mt-3 text-sm text-ok">
            Salvo na planilha — o GS Campo recebe no sync.
          </p>
        ) : null}

        <div className="mt-4 grid gap-3 md:grid-cols-2 lg:grid-cols-3">
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Número *
            </span>
            <input
              required
              value={number}
              onChange={(e) => setNumber(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Tipo
            </span>
            <select
              value={kind}
              onChange={(e) => setKind(e.target.value)}
              className={inputClass}
            >
              {KINDS.map((k) => (
                <option key={k.value} value={k.value}>
                  {k.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Status
            </span>
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className={inputClass}
            >
              {STATUSES.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Cliente
            </span>
            <input
              value={clientName}
              onChange={(e) => setClientName(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Técnico
            </span>
            <input
              value={technicianName}
              onChange={(e) => setTechnicianName(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              TAG
            </span>
            <input
              value={equipmentTag}
              onChange={(e) => setEquipmentTag(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Tipo equipamento
            </span>
            <input
              value={equipmentType}
              onChange={(e) => setEquipmentType(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              N/S
            </span>
            <input
              value={serialNumber}
              onChange={(e) => setSerialNumber(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Fabricante
            </span>
            <input
              value={manufacturer}
              onChange={(e) => setManufacturer(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Modelo
            </span>
            <input
              value={model}
              onChange={(e) => setModel(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Calibrado em
            </span>
            <input
              value={calibrationDate}
              onChange={(e) => setCalibrationDate(e.target.value)}
              className={inputClass}
              placeholder="AAAA-MM-DD"
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Próxima
            </span>
            <input
              value={nextCalibrationDate}
              onChange={(e) => setNextCalibrationDate(e.target.value)}
              className={inputClass}
              placeholder="AAAA-MM-DD"
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Local
            </span>
            <input
              value={site}
              onChange={(e) => setSite(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Fluido
            </span>
            <input
              value={fluid}
              onChange={(e) => setFluid(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Temp. amb.
            </span>
            <input
              value={ambientTemp}
              onChange={(e) => setAmbientTemp(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Umidade
            </span>
            <input
              value={humidity}
              onChange={(e) => setHumidity(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Pressão
            </span>
            <input
              value={pressure}
              onChange={(e) => setPressure(e.target.value)}
              className={inputClass}
            />
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Resultados
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">
          Fator K e incerteza
        </h2>
        <div className="mt-4 grid gap-3 md:grid-cols-2 lg:grid-cols-3">
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Fator K encontrado
            </span>
            <input
              value={meterKFactorFound}
              onChange={(e) => setMeterKFactorFound(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Fator K deixado
            </span>
            <input
              value={meterKFactorLeft}
              onChange={(e) => setMeterKFactorLeft(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Incerteza expandida
            </span>
            <input
              value={measurementUncertainty}
              onChange={(e) => setMeasurementUncertainty(e.target.value)}
              className={inputClass}
              placeholder="ex.: 0,12"
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Fator de cobertura k
            </span>
            <input
              value={coverageFactor}
              onChange={(e) => setCoverageFactor(e.target.value)}
              className={inputClass}
              placeholder="ex.: 2"
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              ν_eff
            </span>
            <input
              value={effectiveDof}
              onChange={(e) => setEffectiveDof(e.target.value)}
              className={inputClass}
            />
          </label>
        </div>
        {preview.linearityPct != null ? (
          <p className="mt-3 text-sm text-navy/55">
            Linearidade calculada:{" "}
            <strong className="text-navy">
              {formatPercent(preview.linearityPct, 3)}
            </strong>
          </p>
        ) : null}
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Padrões
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Usados nesta calibração
            </h2>
          </div>
        </div>
        {catalogStandards.length > 0 ? (
          <div className="mt-3 flex flex-wrap gap-2">
            {catalogStandards.slice(0, 40).map((std) => (
              <button
                key={std.id}
                type="button"
                onClick={() => addCatalogStandard(std)}
                className="rounded-xl border border-navy/12 bg-paper px-3 py-1.5 text-xs font-medium text-navy hover:border-brass/40"
              >
                + {std.name || std.serial || std.id}
              </button>
            ))}
          </div>
        ) : null}
        {standards.length === 0 ? (
          <p className="mt-4 text-sm text-muted">
            Nenhum padrão selecionado — use os chips do cadastro acima.
          </p>
        ) : (
          <ul className="mt-4 space-y-2">
            {standards.map((std, index) => (
              <li
                key={std.id}
                className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-navy/10 bg-paper/70 px-4 py-3"
              >
                <div>
                  <p className="font-medium text-navy">{std.tag || "Padrão"}</p>
                  <p className="text-xs text-navy/50">
                    {[
                      std.description,
                      std.serialNumber && `N/S ${std.serialNumber}`,
                      std.certificate && `Cert. ${std.certificate}`,
                      std.uncertainty && `U ${std.uncertainty}`,
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() =>
                    setStandards((prev) => prev.filter((_, i) => i !== index))
                  }
                  className="text-xs font-medium text-navy/45 hover:text-red-700"
                >
                  Remover
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Pontos de vazão
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Corridas e cálculo de Mf
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              {inverted
                ? "Mf = instrumento ÷ padrão (invertida)"
                : "Mf = padrão ÷ instrumento (mesma regra do app)"}
            </p>
          </div>
          <button
            type="button"
            onClick={() => setPoints((prev) => [...prev, emptyPoint()])}
            className="rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm font-semibold text-navy hover:border-brass/40"
          >
            + Ponto
          </button>
        </div>

        {points.map((point, pointIndex) => {
          const factors = point.verification
            .map((r) =>
              meterFactor(
                parseCalibNumber(r.standardVolume),
                parseCalibNumber(r.objectVolume),
                inverted,
              ),
            )
            .filter((v): v is number => v != null);
          const meanMf = meanOf(factors);
          const old = parseCalibNumber(point.oldMeterFactor);
          const suggested =
            old != null && meanMf != null
              ? correctedMeterFactor(old, meanMf)
              : null;
          const rep = repeatabilityPercent(factors);

          return (
            <article
              key={point.id}
              className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h3 className="font-serif text-lg text-navy">
                  Ponto {pointIndex + 1}
                </h3>
                {points.length > 1 ? (
                  <button
                    type="button"
                    onClick={() =>
                      setPoints((prev) =>
                        prev.filter((_, i) => i !== pointIndex),
                      )
                    }
                    className="text-xs font-medium text-navy/45 hover:text-red-700"
                  >
                    Remover ponto
                  </button>
                ) : null}
              </div>

              <div className="mt-3 grid gap-3 md:grid-cols-3">
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Vazão
                  </span>
                  <input
                    value={point.flowRate}
                    onChange={(e) =>
                      updatePoint(pointIndex, { flowRate: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Unidade
                  </span>
                  <input
                    value={point.flowUnit}
                    onChange={(e) =>
                      updatePoint(pointIndex, { flowUnit: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Mf antigo
                  </span>
                  <input
                    value={point.oldMeterFactor}
                    onChange={(e) =>
                      updatePoint(pointIndex, {
                        oldMeterFactor: e.target.value,
                      })
                    }
                    className={inputClass}
                  />
                </label>
              </div>

              <div className="mt-3 flex flex-wrap gap-2 text-sm">
                <span className="rounded-xl bg-paper px-3 py-1.5">
                  Mf médio {formatCalibNumber(meanMf, 6)}
                </span>
                <span className="rounded-xl bg-paper px-3 py-1.5">
                  Rep. {formatPercent(rep, 3)}
                </span>
                <span className="rounded-xl bg-navy px-3 py-1.5 font-semibold text-brass">
                  Novo {formatCalibNumber(suggested, 6)}
                </span>
              </div>

              <div className="mt-4 space-y-2">
                <div className="flex items-center justify-between">
                  <p className="text-xs font-semibold uppercase tracking-wide text-navy/45">
                    Corridas de verificação
                  </p>
                  <button
                    type="button"
                    onClick={() =>
                      updatePoint(pointIndex, {
                        verification: [...point.verification, emptyRun()],
                      })
                    }
                    className="text-xs font-semibold text-navy/60 hover:text-navy"
                  >
                    + Corrida
                  </button>
                </div>
                {point.verification.map((run, runIndex) => {
                  const std = parseCalibNumber(run.standardVolume);
                  const obj = parseCalibNumber(run.objectVolume);
                  const mf = meterFactor(std, obj, inverted);
                  const err = volumetricErrorPercent(std, obj, inverted);
                  return (
                    <div
                      key={run.id}
                      className="grid gap-2 rounded-2xl border border-navy/10 bg-paper/50 p-3 md:grid-cols-6"
                    >
                      <label className="block text-xs md:col-span-1">
                        <span className="text-navy/45">Padrão</span>
                        <input
                          value={run.standardVolume}
                          onChange={(e) =>
                            updateRun(pointIndex, runIndex, {
                              standardVolume: e.target.value,
                            })
                          }
                          className={inputClass}
                        />
                      </label>
                      <label className="block text-xs md:col-span-1">
                        <span className="text-navy/45">Instrumento</span>
                        <input
                          value={run.objectVolume}
                          onChange={(e) =>
                            updateRun(pointIndex, runIndex, {
                              objectVolume: e.target.value,
                            })
                          }
                          className={inputClass}
                        />
                      </label>
                      <label className="block text-xs">
                        <span className="text-navy/45">ρ</span>
                        <input
                          value={run.density}
                          onChange={(e) =>
                            updateRun(pointIndex, runIndex, {
                              density: e.target.value,
                            })
                          }
                          className={inputClass}
                        />
                      </label>
                      <label className="block text-xs">
                        <span className="text-navy/45">T</span>
                        <input
                          value={run.temperature}
                          onChange={(e) =>
                            updateRun(pointIndex, runIndex, {
                              temperature: e.target.value,
                            })
                          }
                          className={inputClass}
                        />
                      </label>
                      <div className="flex items-end pb-2 text-xs font-semibold text-navy">
                        Mf {formatCalibNumber(mf, 6)}
                      </div>
                      <div className="flex items-end justify-between gap-2 pb-2 text-xs text-navy/70">
                        <span>{formatPercent(err, 3)}</span>
                        {point.verification.length > 1 ? (
                          <button
                            type="button"
                            onClick={() =>
                              updatePoint(pointIndex, {
                                verification: point.verification.filter(
                                  (_, i) => i !== runIndex,
                                ),
                              })
                            }
                            className="text-navy/40 hover:text-red-700"
                          >
                            ×
                          </button>
                        ) : null}
                      </div>
                    </div>
                  );
                })}
              </div>
            </article>
          );
        })}
      </section>

      <div className="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={pending || !number.trim()}
          className="rounded-xl bg-brass px-5 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
        >
          {pending ? "Salvando…" : "Salvar calibração"}
        </button>
        {error ? <p className="text-sm text-red-700">{error}</p> : null}
        {ok ? <p className="text-sm text-ok">Salvo na planilha.</p> : null}
      </div>
    </form>
  );
}
